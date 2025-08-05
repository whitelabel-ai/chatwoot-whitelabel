class SuperAdmin::BillingController < SuperAdmin::ApplicationController
  before_action :set_account, only: [:show, :update_plan, :force_renewal, :suspend, :activate]
  before_action :set_billing_plan, only: [:show_plan, :update_plan_details, :destroy_plan]

  def index
    @accounts = Account.includes(:account_subscription, :billing_plan)
                      .page(params[:page])
                      .per(25)
    
    @accounts = @accounts.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @accounts = @accounts.joins(:account_subscription).where(account_subscriptions: { status: params[:status] }) if params[:status].present?
    
    @total_accounts = Account.count
    @active_subscriptions = AccountSubscription.active_subscriptions.count
    @suspended_accounts = AccountSubscription.where(status: :suspended).count
    @total_revenue = BillingTransaction.successful.sum(:amount)
    @monthly_revenue = BillingTransaction.successful.this_month.sum(:amount)
  end

  def show
    @subscription = @account.current_subscription
    @transactions = @account.billing_transactions.recent.limit(10)
    @usage_report = BillingService.generate_usage_report(@account)
    @consumption_logs = @account.message_consumption_logs
                               .includes(:message, :conversation)
                               .order(created_at: :desc)
                               .limit(20)
  end

  def plans
    @plans = BillingPlan.all.order(:price)
    @plan = BillingPlan.new
  end

  def create_plan
    @plan = BillingPlan.new(plan_params)
    
    if @plan.save
      redirect_to super_admin_billing_plans_path, notice: 'Plan creado exitosamente'
    else
      @plans = BillingPlan.all.order(:price)
      render :plans
    end
  end

  def show_plan
    @accounts_with_plan = @plan.accounts.includes(:account_subscription)
  end

  def update_plan_details
    if @plan.update(plan_params)
      redirect_to super_admin_billing_plan_path(@plan), notice: 'Plan actualizado exitosamente'
    else
      @accounts_with_plan = @plan.accounts.includes(:account_subscription)
      render :show_plan
    end
  end

  def destroy_plan
    if @plan.accounts.any?
      redirect_to super_admin_billing_plan_path(@plan), alert: 'No se puede eliminar un plan que tiene cuentas asociadas'
    else
      @plan.destroy
      redirect_to super_admin_billing_plans_path, notice: 'Plan eliminado exitosamente'
    end
  end

  def update_plan
    new_plan = BillingPlan.find(params[:plan_id])
    
    if BillingService.upgrade_account_plan(@account, new_plan)
      redirect_to super_admin_billing_account_path(@account), notice: 'Plan actualizado exitosamente'
    else
      redirect_to super_admin_billing_account_path(@account), alert: 'Error al actualizar el plan'
    end
  end

  def force_renewal
    subscription = @account.current_subscription
    
    if subscription.renew_period!
      redirect_to super_admin_billing_account_path(@account), notice: 'Renovación forzada exitosamente'
    else
      redirect_to super_admin_billing_account_path(@account), alert: 'Error al forzar la renovación'
    end
  end

  def suspend
    subscription = @account.current_subscription
    
    if subscription.update(status: :suspended)
      redirect_to super_admin_billing_account_path(@account), notice: 'Cuenta suspendida exitosamente'
    else
      redirect_to super_admin_billing_account_path(@account), alert: 'Error al suspender la cuenta'
    end
  end

  def activate
    subscription = @account.current_subscription
    
    if subscription.update(status: :active)
      redirect_to super_admin_billing_account_path(@account), notice: 'Cuenta activada exitosamente'
    else
      redirect_to super_admin_billing_account_path(@account), alert: 'Error al activar la cuenta'
    end
  end

  def transactions
    @transactions = BillingTransaction.includes(:account, :billing_plan)
                                     .order(created_at: :desc)
                                     .page(params[:page])
                                     .per(50)
    
    @transactions = @transactions.where(status: params[:status]) if params[:status].present?
    @transactions = @transactions.joins(:account).where('accounts.name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
  end

  def reports
    @date_range = params[:date_range] || '30_days'
    
    case @date_range
    when 'today'
      start_date = Date.current
      end_date = Date.current
    when '7_days'
      start_date = 7.days.ago.to_date
      end_date = Date.current
    when '30_days'
      start_date = 30.days.ago.to_date
      end_date = Date.current
    when 'this_month'
      start_date = Date.current.beginning_of_month
      end_date = Date.current.end_of_month
    when 'last_month'
      start_date = 1.month.ago.beginning_of_month
      end_date = 1.month.ago.end_of_month
    else
      start_date = 30.days.ago.to_date
      end_date = Date.current
    end

    @report_data = generate_admin_report(start_date, end_date)
    
    respond_to do |format|
      format.html
      format.csv do
        send_data generate_admin_csv_report(@report_data),
                  filename: "billing_report_#{start_date}_#{end_date}.csv",
                  type: 'text/csv'
      end
      format.json { render json: @report_data }
    end
  end

  def reset_monthly_usage
    BillingService.reset_monthly_usage
    redirect_to super_admin_billing_index_path, notice: 'Uso mensual reiniciado para todas las cuentas'
  end

  def check_exceeded_accounts
    BillingService.check_and_suspend_exceeded_accounts
    redirect_to super_admin_billing_index_path, notice: 'Verificación de límites completada'
  end

  private

  def set_account
    @account = Account.find(params[:id] || params[:account_id])
  end

  def set_billing_plan
    @plan = BillingPlan.find(params[:id] || params[:plan_id])
  end

  def plan_params
    params.require(:billing_plan).permit(
      :name, :description, :monthly_message_limit, :price, :currency,
      :active, :payment_link_url, features: {}
    )
  end

  def generate_admin_report(start_date, end_date)
    {
      period: { start: start_date, end: end_date },
      summary: {
        total_accounts: Account.count,
        active_subscriptions: AccountSubscription.active_subscriptions.count,
        suspended_accounts: AccountSubscription.where(status: :suspended).count,
        total_revenue: BillingTransaction.successful.sum(:amount),
        period_revenue: BillingTransaction.successful
                                         .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                                         .sum(:amount),
        total_messages_consumed: MessageConsumptionLog.where(consumption_date: start_date..end_date).count
      },
      plans_usage: BillingPlan.joins(:account_subscriptions)
                              .group('billing_plans.name')
                              .count,
      daily_revenue: BillingTransaction.successful
                                      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                                      .group('DATE(created_at)')
                                      .sum(:amount),
      top_consuming_accounts: Account.joins(:message_consumption_logs)
                                    .where(message_consumption_logs: { consumption_date: start_date..end_date })
                                    .group('accounts.name')
                                    .count
                                    .sort_by { |_, count| -count }
                                    .first(10)
    }
  end

  def generate_admin_csv_report(report_data)
    CSV.generate(headers: true) do |csv|
      csv << ['Métrica', 'Valor']
      
      # Summary data
      report_data[:summary].each do |key, value|
        csv << [key.to_s.humanize, value]
      end
      
      csv << []
      csv << ['Plan', 'Cuentas Activas']
      report_data[:plans_usage].each do |plan, count|
        csv << [plan, count]
      end
      
      csv << []
      csv << ['Cuenta', 'Mensajes Consumidos']
      report_data[:top_consuming_accounts].each do |account, count|
        csv << [account, count]
      end
    end
  end
end