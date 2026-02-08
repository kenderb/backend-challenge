# frozen_string_literal: true

class CreateIdempotencyKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :idempotency_keys do |t|
      t.string :key, null: false
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end

    add_index :idempotency_keys, :key, unique: true
  end
end
