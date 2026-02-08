# frozen_string_literal: true

FactoryBot.define do
  factory :idempotency_key do
    key { "idem-#{SecureRandom.uuid}" }
    association :order
  end
end
