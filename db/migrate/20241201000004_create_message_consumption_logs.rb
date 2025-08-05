class CreateMessageConsumptionLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :message_consumption_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.references :conversation, null: false, foreign_key: true
      t.date :consumption_date, null: false
      t.integer :message_type, null: false
      t.string :source_type # 'agent', 'bot', 'webhook', 'api'
      t.integer :messages_remaining_after
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index [:account_id, :consumption_date], name: 'idx_msg_logs_account_date'
      t.index [:account_id, :created_at], name: 'idx_msg_logs_account_created'
    end

    # Add enum constraint for message_type
    add_check_constraint :message_consumption_logs, "message_type IN (0, 1, 2, 3, 4)", name: "message_consumption_logs_type_check"
  end
end