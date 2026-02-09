# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clients::CustomerServiceClient do
  let(:adapter) { instance_double(ExternalApis::CustomerClient, fetch_customer: metadata) }
  let(:metadata) { ExternalApis::CustomerMetadata.new(customer_name: "Jane", address: "123 Main St", orders_count: 0) }

  describe "#fetch_customer" do
    it "delegates to the injected adapter" do
      client = described_class.new(adapter: adapter)

      result = client.fetch_customer(1)

      expect(result).to eq(metadata)
      expect(adapter).to have_received(:fetch_customer).with(1)
    end

    it "defaults to ExternalApis::CustomerClient when adapter is nil" do
      ENV["CUSTOMER_SERVICE_URL"] = "http://customer-service.test"
      ENV["INTERNAL_API_KEY"] = "test-key"
      stub_request(:get, "http://customer-service.test/customers/1")
        .with(headers: { "X-Internal-Api-Key" => "test-key" })
        .to_return(status: 200, body: { name: "Jane", address: "123 Main St", orders_count: 0 }.to_json, headers: { "Content-Type" => "application/json" })

      client = described_class.new
      result = client.fetch_customer(1)

      expect(result.customer_name).to eq("Jane")
      expect(result.orders_count).to eq(0)
    ensure
      ENV.delete("CUSTOMER_SERVICE_URL")
      ENV.delete("INTERNAL_API_KEY")
    end
  end
end
