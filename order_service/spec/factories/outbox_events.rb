# frozen_string_literal: true

FactoryBot.define do
  factory :outbox_event do
    aggregate_type { "Order" }
    aggregate_id { "1" }
    event_type { "order.created" }
    payload { { order_id: 1, customer_id: 1, product_name: "Widget", quantity: 1, price: 9.99 } }
    status { :pending }
  end
end
