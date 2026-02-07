FactoryBot.define do
  factory :customer do
    customer_name { "MyString" }
    address { "MyString" }
    orders_count { 1 }
  end
end
