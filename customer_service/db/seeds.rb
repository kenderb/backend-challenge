# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
# Idempotent: safe to run multiple times.

CUSTOMERS = [
  { name: "Alice Johnson", address: "100 Oak Avenue, Springfield" },
  { name: "Bob Smith", address: "200 Pine Road, Riverside" },
  { name: "Carol Williams", address: "300 Elm Street, Fairview" },
  { name: "David Brown", address: "400 Maple Drive, Lakeside" },
  { name: "Eve Davis", address: "500 Cedar Lane, Hillcrest" },
  { name: "Frank Miller", address: "600 Birch Blvd, Brookside" },
  { name: "Grace Wilson", address: "700 Walnut Way, Greenwood" },
  { name: "Henry Moore", address: "800 Chestnut Circle, Milltown" },
  { name: "Ivy Taylor", address: "900 Ash Avenue, Northfield" },
  { name: "Jack Anderson", address: "1000 Willow Way, Southport" }
].freeze

if Customer.count.zero?
  CUSTOMERS.each do |attrs|
    Customer.create!(attrs.merge(orders_count: 0))
  end
end
