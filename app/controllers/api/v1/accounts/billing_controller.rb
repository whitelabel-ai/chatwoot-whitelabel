class Api::V1::Accounts::BillingController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    @subscription = Current.account.current_subscription
    @plan = @subscription.billing_plan
    @usage_data = billing_usage_data
  end

  def plans
    @plans = BillingPlan.active.order(:price)
  end

  def transactions
    @transactions = Current.account.billing_transactions
                                  .includes(:billing_plan)
                                  .recent
                                  .page(params[:page])
                                  .per(20)
  end

  def usage_report
    start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    end_date = params[:end_date]&.to_date || Date.current.end_of_month
    
    @report = BillingService.generate_usage_report(Current.account, start_date, end_date)
    
    respond_to do |format|
      format.json { render json: @report }
      format.csv do
        send_data generate_csv_report(@report), 
                  filename: "usage_report_#{Current.account.id}_#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end

  def create_payment
    @plan = BillingPlan.find(params[:plan_id])
    
    unless @plan.active?
      render json: { error: 'Plan no disponible' }, status: :unprocessable_entity
      return
    end

    @transaction = BillingService.create_transaction(
      account: Current.account,
      billing_plan: @plan,
      payment_gateway: params[:payment_gateway] || 'wompi',
      metadata: {
        user_id: Current.user.id,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    )

    render json: {
      transaction_id: @transaction.transaction_id,
      amount: @transaction.formatted_amount,
      currency: @transaction.currency,
      payment_url: generate_payment_url(@transaction)
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def payment_callback
    transaction_id = params[:transaction_id]
    status = params[:status]
    gateway_response = params.except(:controller, :action, :account_id)

    case status
    when 'approved', 'success'
      @transaction = BillingService.process_successful_payment(transaction_id, gateway_response)
      render json: { status: 'success', message: 'Pago procesado exitosamente' }
    when 'declined', 'failed'
      @transaction = BillingService.process_failed_payment(transaction_id, params[:error_message])
      render json: { status: 'failed', message: 'El pago no pudo ser procesado' }, status: :unprocessable_entity
    else
      render json: { status: 'pending', message: 'Pago en proceso' }
    end
  end

  def upgrade_plan
    @new_plan = BillingPlan.find(params[:plan_id])
    @current_plan = Current.account.current_plan

    unless @new_plan.active?
      render json: { error: 'Plan no disponible' }, status: :unprocessable_entity
      return
    end

    if @new_plan.monthly_message_limit <= @current_plan.monthly_message_limit
      render json: { error: 'Solo puedes actualizar a un plan superior' }, status: :unprocessable_entity
      return
    end

    @transaction = BillingService.upgrade_account_plan(Current.account, @new_plan)
    
    render json: {
      message: 'Plan actualizado exitosamente',
      new_plan: @new_plan.name,
      new_limit: @new_plan.monthly_message_limit
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def alerts
    subscription = Current.account.current_subscription
    alerts = []

    if subscription.limit_exceeded?
      alerts << {
        type: 'danger',
        title: 'Límite de mensajes excedido',
        message: 'Has alcanzado el límite de mensajes de tu plan. Actualiza tu plan para continuar enviando mensajes.',
        action: 'upgrade_plan'
      }
    elsif subscription.near_limit?(80)
      alerts << {
        type: 'warning',
        title: 'Cerca del límite de mensajes',
        message: "Has usado #{subscription.usage_percentage.round}% de tus mensajes mensuales.",
        action: 'view_usage'
      }
    end

    if subscription.days_until_renewal <= 3
      alerts << {
        type: 'info',
        title: 'Renovación próxima',
        message: "Tu plan se renovará en #{subscription.days_until_renewal} días.",
        action: 'view_billing'
      }
    end

    render json: { alerts: alerts }
  end

  private

  def check_authorization
    authorize! :manage, :account_billing
  end

  def billing_usage_data
    subscription = Current.account.current_subscription
    
    {
      messages_used: subscription.messages_used,
      messages_limit: subscription.messages_limit,
      messages_remaining: subscription.messages_remaining,
      usage_percentage: subscription.usage_percentage,
      days_until_renewal: subscription.days_until_renewal,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      billing_status: Current.account.billing_status
    }
  end

  def generate_payment_url(transaction)
    # This would integrate with the actual payment gateway
    # For now, return the plan's payment link or a generic URL
    transaction.billing_plan.payment_link_url || "#payment/#{transaction.transaction_id}"
  end

  def generate_csv_report(report)
    CSV.generate(headers: true) do |csv|
      csv << ['Métrica', 'Valor']
      csv << ['Cuenta', report[:account_name]]
      csv << ['Plan Actual', report[:current_plan][:name]]
      csv << ['Límite de Mensajes', report[:current_plan][:limit]]
      csv << ['Mensajes Usados', report[:usage][:messages_used]]
      csv << ['Mensajes Restantes', report[:usage][:messages_remaining]]
      csv << ['Porcentaje de Uso', "#{report[:usage][:usage_percentage]}%"]
      csv << ['Período Inicio', report[:period][:start]]
      csv << ['Período Fin', report[:period][:end]]
    end
  end
end