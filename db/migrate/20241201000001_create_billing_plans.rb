class CreateBillingPlans < ActiveRecord::Migration[7.0]
  def change
    create_table :billing_plans do |t|
      t.string :name, null: false
      t.text :description
      t.integer :monthly_message_limit, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.boolean :active, default: true, null: false
      t.string :payment_link_url
      t.jsonb :features, default: {}
      t.timestamps

      t.index :name, unique: true
      t.index :active
    end
  end
end