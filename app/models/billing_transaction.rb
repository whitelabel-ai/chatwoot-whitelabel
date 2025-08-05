# == Schema Information
#
# Table name: billing_transactions
#
#  id               :bigint           not null, primary key
#  amount           :decimal(10, 2)   not null
#  currency         :string           default("USD"), not null
#  gateway_response :text
#  invoice_url      :string
#  metadata         :jsonb
#  payment_gateway  :string           default("wompi")
#  payment_method   :string
#  processed_at     :datetime
#  status           :integer          default("pending"), not null
#  transaction_type :integer          default("purchase"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  billing_plan_id  :bigint           not null
#  transaction_id   :string           not null
#
# Indexes
#
#  index_billing_transactions_on_account_id        (account_id)
#  index_billing_transactions_on_billing_plan_id   (billing_plan_id)
#  index_billing_transactions_on_processed_at      (processed_at)
#  index_billing_transactions_on_status            (status)
#  index_billing_transactions_on_transaction_id    (transaction_id) UNIQUE
#  index_billing_transactions_on_transaction_type  (transaction_type)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (billing_plan_id => billing_plans.id)
#

class BillingTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :billing_plan

  enum transaction_type: {
    purchase: 0,
    refund: 1,
    upgrade: 2
  }

  enum status: {
    pending: 0,
    completed: 1,
    failed: 2,
    cancelled: 3
  }

  validates :transaction_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :payment_gateway, presence: true

  scope :successful, -> { where(status: :completed) }
  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }

  def formatted_amount
    "#{currency_symbol}#{amount.to_i}"
  end

  def currency_symbol
    case currency.upcase
    when 'USD'
      '$'
    when 'EUR'
      '€'
    when 'COP'
      '$'
    else
      currency
    end
  end

  def gateway_name
    payment_gateway.capitalize
  end

  def success?
    completed?
  end

  def can_refund?
    completed? && purchase? && processed_at && processed_at > 30.days.ago
  end

  def mark_as_completed!(gateway_response_data = {})
    update!(
      status: :completed,
      processed_at: Time.current,
      gateway_response: gateway_response_data.to_json
    )
  end

  def mark_as_failed!(error_message = nil)
    update!(
      status: :failed,
      gateway_response: { error: error_message }.to_json
    )
  end

  def self.generate_transaction_id
    "TXN_#{SecureRandom.hex(8).upcase}_#{Time.current.to_i}"
  end
end
