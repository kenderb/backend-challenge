# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    customer_id { 1 }
    product_name { "Widget #{SecureRandom.hex(4)}" }
    quantity { 1 }
    price { 9.99 }
    status { :pending }
  end
end
