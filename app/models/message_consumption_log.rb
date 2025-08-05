# == Schema Information
#
# Table name: message_consumption_logs
#
#  id                       :bigint           not null, primary key
#  consumption_date         :date             not null
#  message_type             :integer          not null
#  messages_remaining_after :integer
#  metadata                 :jsonb
#  source_type              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  conversation_id          :bigint           not null
#  message_id               :bigint           not null
#
# Indexes
#
#  idx_msg_logs_account_created                       (account_id,created_at)
#  idx_msg_logs_account_date                          (account_id,consumption_date)
#  index_message_consumption_logs_on_account_id       (account_id)
#  index_message_consumption_logs_on_conversation_id  (conversation_id)
#  index_message_consumption_logs_on_message_id       (message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (message_id => messages.id)
#

class MessageConsumptionLog < ApplicationRecord
  belongs_to :account
  belongs_to :message
  belongs_to :conversation

  enum message_type: {
    incoming: 0,
    outgoing: 1,
    activity: 2,
    template: 3,
    input_csat: 4
  }

  validates :consumption_date, presence: true
  validates :message_type, presence: true
  validates :messages_remaining_after, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_date_range, ->(start_date, end_date) { where(consumption_date: start_date..end_date) }
  scope :this_month, -> { where(consumption_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :today, -> { where(consumption_date: Date.current) }
  scope :by_source, ->(source) { where(source_type: source) }

  def self.log_message_consumption(message, remaining_messages = nil)
    create!(
      account: message.account,
      message: message,
      conversation: message.conversation,
      consumption_date: Date.current,
      message_type: message.message_type,
      source_type: determine_source_type(message),
      messages_remaining_after: remaining_messages,
      metadata: {
        inbox_id: message.inbox_id,
        sender_type: message.sender_type,
        sender_id: message.sender_id
      }
    )
  end

  def self.daily_consumption_for_account(account_id, date = Date.current)
    where(account_id: account_id, consumption_date: date).count
  end

  def self.monthly_consumption_for_account(account_id, month = Date.current.beginning_of_month)
    where(
      account_id: account_id,
      consumption_date: month..month.end_of_month
    ).count
  end

  def self.consumption_by_source(account_id, start_date = Date.current.beginning_of_month)
    where(account_id: account_id)
      .where('consumption_date >= ?', start_date)
      .group(:source_type)
      .count
  end

  def self.daily_consumption_trend(account_id, days = 30)
    where(account_id: account_id)
      .where('consumption_date >= ?', days.days.ago)
      .group(:consumption_date)
      .count
      .transform_keys(&:to_s)
  end

  private

  def self.determine_source_type(message)
    return 'webhook' if message.content_attributes&.dig('external_source_id')
    return 'api' if message.source_id.present?
    return 'bot' if message.sender_type == 'AgentBot'
    return 'agent' if message.sender_type == 'User'
    
    'system'
  end
end
