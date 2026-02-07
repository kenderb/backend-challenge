# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "faker"

# Create 10 initial customers with Faker-generated names and addresses (idempotent)
if Customer.count.zero?
  10.times do
    Customer.create!(
      customer_name: Faker::Name.name,
      address: Faker::Address.full_address
    )
  end
end
