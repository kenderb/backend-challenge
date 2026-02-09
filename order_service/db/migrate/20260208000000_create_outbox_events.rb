# frozen_string_literal: true

class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_events do |t|
      t.string :aggregate_type, null: false
      t.string :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.datetime :processed_at
      t.text :error_message

      t.timestamps
    end

    add_index :outbox_events, :status
    add_index :outbox_events, [:status, :created_at]
  end
end
