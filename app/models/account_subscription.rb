# == Schema Information
#
# Table name: account_subscriptions
#
#  id                   :bigint           not null, primary key
#  current_period_end   :date
#  current_period_start :date
#  last_reset_at        :datetime
#  messages_limit       :integer          not null
#  messages_used        :integer          default(0), not null
#  metadata             :jsonb
#  status               :integer          default("active"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  billing_plan_id      :bigint           not null
#
# Indexes
#
#  index_account_subscriptions_on_account_id          (account_id) UNIQUE
#  index_account_subscriptions_on_billing_plan_id     (billing_plan_id)
#  index_account_subscriptions_on_current_period_end  (current_period_end)
#  index_account_subscriptions_on_status              (status)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (billing_plan_id => billing_plans.id)
#

class AccountSubscription < ApplicationRecord
  belongs_to :account
  belongs_to :billing_plan
  has_many :message_consumption_logs, through: :account

  enum status: {
    active: 0,
    suspended: 1,
    cancelled: 2,
    expired: 3
  }

  validates :messages_limit, presence: true, numericality: { greater_than: 0 }
  validates :messages_used, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_messages_limit, on: :create
  before_validation :set_current_period, on: :create

  scope :active_subscriptions, -> { where(status: :active) }
  scope :expired_this_month, -> { where('current_period_end < ?', Date.current) }

  def messages_remaining
    [messages_limit - messages_used, 0].max
  end

  def usage_percentage
    return 0 if messages_limit.zero?
    
    ((messages_used.to_f / messages_limit) * 100).round(2)
  end

  def near_limit?(threshold = 80)
    usage_percentage >= threshold
  end

  def limit_exceeded?
    messages_used >= messages_limit
  end

  def can_send_messages?
    active? && !limit_exceeded?
  end

  def days_until_renewal
    return 0 unless current_period_end
    
    (current_period_end - Date.current).to_i
  end

  def renew_period!
    update!(
      current_period_start: Date.current.beginning_of_month,
      current_period_end: Date.current.end_of_month,
      messages_used: 0,
      last_reset_at: Time.current
    )
  end

  def consume_message!
    return false unless can_send_messages?
    
    increment!(:messages_used)
    true
  end

  def add_messages!(count)
    increment!(:messages_limit, count)
  end

  def expired?
    current_period_end && current_period_end < Date.current
  end

  def auto_renewable?
    billing_plan.feature_enabled?('auto_renewal')
  end

  private

  def set_messages_limit
    self.messages_limit = billing_plan.monthly_message_limit if billing_plan
  end

  def set_current_period
    now = Date.current
    self.current_period_start = now.beginning_of_month
    self.current_period_end = now.end_of_month
    self.last_reset_at = Time.current
  end
end
