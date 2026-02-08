# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  belongs_to :order

  validates :key, presence: true, uniqueness: true
end
