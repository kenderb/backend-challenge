FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "Customer #{n}" }
    address { "123 Main St, City" }
    orders_count { 0 }
  end
end
