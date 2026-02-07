# frozen_string_literal: true

class Customer < ApplicationRecord
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :address, presence: true
  validates :orders_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
