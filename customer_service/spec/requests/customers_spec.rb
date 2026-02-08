# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /customers/:id", type: :request do
  let(:customer) { create(:customer, name: "Test Customer", address: "123 Test St", orders_count: 0) }
  let(:valid_api_key) { "test-internal-api-key" }
  # Use an allowed host so HostAuthorization does not return 403 (e.g. in Docker)
  let(:request_headers) { { "Host" => "www.example.com" } }

  before do
    # Stub both sources so the expected key is under our control (works with ENV in Docker or credentials locally)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("INTERNAL_API_KEY").and_return(valid_api_key)
  end

  context "without X-Internal-Api-Key header" do
    it "returns 401 Unauthorized" do
      get customer_path(customer), headers: request_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with wrong X-Internal-Api-Key header" do
    it "returns 401 Unauthorized" do
      get customer_path(customer), headers: request_headers.merge("X-Internal-Api-Key" => "wrong-key")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with valid X-Internal-Api-Key header" do
    it "returns 200 OK and the customer as JSON" do
      get customer_path(customer), headers: request_headers.merge("X-Internal-Api-Key" => valid_api_key)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(customer.id)
      expect(json["name"]).to eq("Test Customer")
      expect(json["address"]).to eq("123 Test St")
      expect(json["orders_count"]).to eq(0)
    end
  end
end
