# frozen_string_literal: true

class Order < ApplicationRecord
  has_one :idempotency_key, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, cancelled: 3 }, default: :pending

  validates :customer_id, presence: true
  validates :product_name, presence: true, uniqueness: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
