class CreateBillingTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :billing_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :billing_plan, null: false, foreign_key: true
      t.string :transaction_id, null: false
      t.integer :transaction_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.string :payment_method
      t.string :payment_gateway, default: 'wompi'
      t.text :gateway_response
      t.string :invoice_url
      t.datetime :processed_at
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :transaction_id, unique: true
      t.index :status
      t.index :transaction_type
      t.index :processed_at
    end

    # Add enum constraints
    add_check_constraint :billing_transactions, "transaction_type IN (0, 1, 2)", name: "billing_transactions_type_check"
    add_check_constraint :billing_transactions, "status IN (0, 1, 2, 3)", name: "billing_transactions_status_check"
  end
end