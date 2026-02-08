# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.integer :customer_id, null: false
      t.string :product_name, null: false
      t.integer :quantity, null: false, default: 0
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :orders, :customer_id
    add_index :orders, :product_name, unique: true
    add_index :orders, :status
  end
end
