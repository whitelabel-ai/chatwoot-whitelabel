# == Schema Information
#
# Table name: billing_plans
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  currency              :string           default("USD"), not null
#  description           :text
#  features              :jsonb
#  monthly_message_limit :integer          not null
#  name                  :string           not null
#  payment_link_url      :string
#  price                 :decimal(10, 2)   not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_billing_plans_on_active  (active)
#  index_billing_plans_on_name    (name) UNIQUE
#

class BillingPlan < ApplicationRecord
  has_many :account_subscriptions, dependent: :restrict_with_error
  has_many :billing_transactions, dependent: :restrict_with_error
  has_many :accounts, through: :account_subscriptions

  validates :name, presence: true, uniqueness: true
  validates :monthly_message_limit, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  scope :active, -> { where(active: true) }
  scope :free, -> { where(price: 0) }
  scope :paid, -> { where('price > 0') }

  def free?
    price.zero?
  end

  def paid?
    price > 0
  end

  def formatted_price
    return 'Gratis' if free?
    
    "#{currency_symbol}#{price.to_i}"
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

  def feature_enabled?(feature_name)
    features[feature_name.to_s] == true
  end

  def self.default_free_plan
    find_by(name: 'Plan Gratuito') || first
  end
end
