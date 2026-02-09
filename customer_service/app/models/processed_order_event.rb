# frozen_string_literal: true

class ProcessedOrderEvent < ApplicationRecord
  belongs_to :customer

  validates :event_id, presence: true, uniqueness: true
end
