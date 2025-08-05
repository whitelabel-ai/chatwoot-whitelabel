class CreateDefaultBillingPlan < ActiveRecord::Migration[7.0]
  def up
    # Create default free plan
    BillingPlan.create!(
      name: 'Plan Gratuito',
      description: 'Plan gratuito con 100 mensajes mensuales',
      monthly_message_limit: 100,
      price: 0.0,
      currency: 'USD',
      active: true,
      features: {
        'auto_renewal' => true,
        'support_level' => 'basic',
        'api_access' => true
      }
    )
  end

  def down
    BillingPlan.find_by(name: 'Plan Gratuito')&.destroy
  end
end