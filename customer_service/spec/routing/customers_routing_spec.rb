# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customers routes", type: :routing do
  describe "GET /customers/:id" do
    it "routes to customers#show" do
      expect(get: "/customers/42").to route_to(
        controller: "customers",
        action: "show",
        id: "42"
      )
    end

    it "routes customer_path(id) to customers#show" do
      expect(get: customer_path(42)).to route_to(
        controller: "customers",
        action: "show",
        id: "42"
      )
    end
  end
end
