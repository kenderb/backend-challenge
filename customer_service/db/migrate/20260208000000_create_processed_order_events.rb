# frozen_string_literal: true

class CreateProcessedOrderEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :processed_order_events do |t|
      t.string :event_id, null: false
      t.bigint :customer_id, null: false

      t.timestamps
    end

    add_index :processed_order_events, :event_id, unique: true
    add_index :processed_order_events, :customer_id
    add_foreign_key :processed_order_events, :customers
  end
end
