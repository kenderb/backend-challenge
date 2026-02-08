# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalApis::CustomerClient do
  let(:base_url) { "http://customer-service.test" }
  let(:api_key) { "test-internal-key" }
  let(:client) { described_class.new(base_url: base_url, api_key: api_key) }

  before do
    Stoplight.default_data_store = Stoplight::DataStore::Memory.new
  end

  describe "#fetch_customer" do
    context "when the customer exists (happy path)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(
            status: 200,
            body: { name: "Jane", address: "123 Main St", orders_count: 0 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns a CustomerMetadata with customer_name, address, and orders_count" do
        result = client.fetch_customer(1)

        expect(result).to be_a(ExternalApis::CustomerMetadata)
        expect(result.customer_name).to eq("Jane")
        expect(result.address).to eq("123 Main St")
        expect(result.orders_count).to eq(0)
      end

      it "does not return raw HTTP response" do
        result = client.fetch_customer(1)

        expect(result).not_to respond_to(:status)
        expect(result).not_to respond_to(:body)
      end
    end

    context "when the customer is not found (404)" do
      before do
        stub_request(:get, "#{base_url}/customers/999")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 404)
      end

      it "raises Errors::CustomerNotFound" do
        expect { client.fetch_customer(999) }.to raise_error do |error|
          expect(error.class.name).to eq("Errors::CustomerNotFound")
        end
      end
    end

    context "when the customer service returns 5xx (resilience path)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises Errors::ServiceUnavailable and does not return raw HTTP" do
        expect { client.fetch_customer(1) }.to raise_error do |error|
          expect(error.class.name).to eq("Errors::ServiceUnavailable")
        end
      end
    end

    context "when the request times out (resilience path)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_timeout
      end

      it "raises Errors::ServiceUnavailable" do
        expect { client.fetch_customer(1) }.to raise_error do |error|
          expect(error.class.name).to eq("Errors::ServiceUnavailable")
        end
      end
    end

    context "when verifying X-Internal-Api-Key header" do
      let(:customer_stub) do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(
            status: 200,
            body: { name: "Jane", address: "123 Main St", orders_count: 0 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "sends X-Internal-Api-Key on every request" do
        customer_stub
        client.fetch_customer(1)

        expect(customer_stub).to have_been_requested
      end

      it "rejects requests without the correct key" do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => "wrong-key" })
          .to_return(status: 401)

        client_wrong_key = described_class.new(base_url: base_url, api_key: "wrong-key")
        expect { client_wrong_key.fetch_customer(1) }.to raise_error do |error|
          expect(error.class.name).to eq("Errors::ServiceUnavailable")
        end
      end
    end
  end
end
