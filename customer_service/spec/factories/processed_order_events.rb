# frozen_string_literal: true

FactoryBot.define do
  factory :processed_order_event do
    association :customer
    sequence(:event_id) { |n| "evt-#{n}-#{SecureRandom.hex(4)}" }
  end
end
