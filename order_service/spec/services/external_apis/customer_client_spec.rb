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

      it "data integrity: correctly parses customer_name, address, and orders_count from JSON" do
        stub_request(:get, "#{base_url}/customers/42")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(
            status: 200,
            body: { name: "Alice Doe", address: "456 Oak Ave", orders_count: 7 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client.fetch_customer(42)

        expect(result.customer_name).to eq("Alice Doe")
        expect(result.address).to eq("456 Oak Ave")
        expect(result.orders_count).to eq(7)
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

      it "raises Errors::CustomerServiceUnavailable and does not return raw HTTP" do
        expect { client.fetch_customer(1) }.to raise_error(Errors::CustomerServiceUnavailable)
      end
    end

    context "when the customer service returns 503 (down service)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 503, body: "Service Unavailable")
      end

      it "raises Errors::CustomerServiceUnavailable" do
        expect { client.fetch_customer(1) }.to raise_error(Errors::CustomerServiceUnavailable)
      end
    end

    context "when the service is slow (request times out)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_timeout
      end

      it "handles latency gracefully and raises CustomerServiceUnavailable after retries" do
        expect { client.fetch_customer(1) }.to raise_error(Errors::CustomerServiceUnavailable)
      end
    end

    context "when the service is down (circuit breaker opens after multiple 500s)" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 500, body: "Error")
      end

      it "triggers the circuit breaker and then fails fast without hitting the network" do
        # Trip the circuit (threshold 3)
        3.times do
          client.fetch_customer(1)
        rescue Errors::CustomerServiceUnavailable
          # expected
        end

        # Fourth call: circuit open, should raise without making a new request
        expect { client.fetch_customer(1) }.to raise_error(Errors::CustomerServiceUnavailable)
        expect(WebMock).to have_requested(:get, "#{base_url}/customers/1").times(3)
      end
    end

    context "when the response has invalid contract (malformed or missing fields)" do
      it "raises CustomerServiceUnavailable when response body is malformed JSON" do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 200, body: "not valid json", headers: { "Content-Type" => "text/plain" })

        expect { client.fetch_customer(1) }.to raise_error(Errors::CustomerServiceUnavailable)
      end

      it "treats missing orders_count as 0" do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(
            status: 200,
            body: { name: "Jane", address: "123 Main St" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client.fetch_customer(1)

        expect(result.customer_name).to eq("Jane")
        expect(result.address).to eq("123 Main St")
        expect(result.orders_count).to eq(0)
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
        expect { client_wrong_key.fetch_customer(1) }.to raise_error(Errors::UnauthorizedError)
      end
    end
  end
end
