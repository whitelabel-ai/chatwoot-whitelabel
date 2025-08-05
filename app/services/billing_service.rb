class BillingService
  class << self
    def create_transaction(account:, billing_plan:, payment_gateway: 'wompi', metadata: {})
      transaction_id = BillingTransaction.generate_transaction_id
      
      BillingTransaction.create!(
        account: account,
        billing_plan: billing_plan,
        transaction_id: transaction_id,
        transaction_type: :purchase,
        status: :pending,
        amount: billing_plan.price,
        currency: billing_plan.currency,
        payment_gateway: payment_gateway,
        metadata: metadata
      )
    end

    def process_successful_payment(transaction_id, gateway_response = {})
      transaction = BillingTransaction.find_by!(transaction_id: transaction_id)
      
      ActiveRecord::Base.transaction do
        # Mark transaction as completed
        transaction.mark_as_completed!(gateway_response)
        
        # Update account subscription
        update_account_subscription(transaction)
        
        # Send confirmation notifications
        send_payment_confirmation(transaction)
      end
      
      transaction
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Transaction not found: #{transaction_id}"
      nil
    end

    def process_failed_payment(transaction_id, error_message = nil)
      transaction = BillingTransaction.find_by!(transaction_id: transaction_id)
      transaction.mark_as_failed!(error_message)
      
      # Send failure notification
      send_payment_failure_notification(transaction)
      
      transaction
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Transaction not found: #{transaction_id}"
      nil
    end

    def upgrade_account_plan(account, new_plan)
      current_subscription = account.current_subscription
      
      ActiveRecord::Base.transaction do
        # Create upgrade transaction
        transaction = create_transaction(
          account: account,
          billing_plan: new_plan,
          metadata: {
            upgrade_from: current_subscription.billing_plan.name,
            upgrade_to: new_plan.name
          }
        )
        transaction.update!(transaction_type: :upgrade)
        
        # Update subscription
        current_subscription.update!(
          billing_plan: new_plan,
          messages_limit: new_plan.monthly_message_limit,
          status: :active
        )
        
        transaction
      end
    end

    def reset_monthly_usage
      AccountSubscription.active_subscriptions.find_each do |subscription|
        next unless subscription.auto_renewable?
        next unless subscription.expired?
        
        subscription.renew_period!
        Rails.logger.info "Reset monthly usage for account #{subscription.account_id}"
      end
    end

    def check_and_suspend_exceeded_accounts
      AccountSubscription.active_subscriptions.find_each do |subscription|
        next unless subscription.limit_exceeded?
        
        subscription.update!(status: :suspended)
        send_limit_exceeded_notification(subscription)
        
        Rails.logger.info "Suspended account #{subscription.account_id} for exceeding message limit"
      end
    end

    def generate_usage_report(account, start_date = nil, end_date = nil)
      start_date ||= Date.current.beginning_of_month
      end_date ||= Date.current.end_of_month
      
      {
        account_id: account.id,
        account_name: account.name,
        period: {
          start: start_date,
          end: end_date
        },
        current_plan: {
          name: account.current_plan.name,
          limit: account.messages_limit,
          price: account.current_plan.formatted_price
        },
        usage: {
          messages_used: account.messages_used_this_month,
          messages_remaining: account.messages_remaining,
          usage_percentage: account.usage_percentage
        },
        consumption_by_source: MessageConsumptionLog.consumption_by_source(account.id, start_date),
        daily_trend: MessageConsumptionLog.daily_consumption_trend(account.id, 30),
        transactions: account.billing_transactions.recent.limit(10).map do |transaction|
          {
            id: transaction.transaction_id,
            type: transaction.transaction_type,
            amount: transaction.formatted_amount,
            status: transaction.status,
            date: transaction.created_at,
            plan: transaction.billing_plan.name
          }
        end
      }
    end

    private

    def update_account_subscription(transaction)
      account = transaction.account
      new_plan = transaction.billing_plan
      
      subscription = account.current_subscription
      
      if transaction.upgrade?
        # For upgrades, just update the plan and add messages
        subscription.update!(
          billing_plan: new_plan,
          messages_limit: new_plan.monthly_message_limit,
          status: :active
        )
      else
        # For new purchases, reset the period and messages
        subscription.update!(
          billing_plan: new_plan,
          messages_limit: new_plan.monthly_message_limit,
          messages_used: 0,
          status: :active,
          current_period_start: Date.current.beginning_of_month,
          current_period_end: Date.current.end_of_month,
          last_reset_at: Time.current
        )
      end
    end

    def send_payment_confirmation(transaction)
      # TODO: Implement email/webhook notifications
      Rails.logger.info "Payment confirmed for account #{transaction.account_id}: #{transaction.formatted_amount}"
    end

    def send_payment_failure_notification(transaction)
      # TODO: Implement email/webhook notifications
      Rails.logger.error "Payment failed for account #{transaction.account_id}: #{transaction.formatted_amount}"
    end

    def send_limit_exceeded_notification(subscription)
      # TODO: Implement email/webhook notifications
      Rails.logger.warn "Account #{subscription.account_id} exceeded message limit"
    end
  end
end