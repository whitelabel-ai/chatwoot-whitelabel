class CreateAccountSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :account_subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.references :billing_plan, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.date :current_period_start
      t.date :current_period_end
      t.integer :messages_used, default: 0, null: false
      t.integer :messages_limit, null: false
      t.datetime :last_reset_at
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :status
      t.index :current_period_end
    end

    # Add enum for status
    add_check_constraint :account_subscriptions, "status IN (0, 1, 2, 3)", name: "account_subscriptions_status_check"
  end
end