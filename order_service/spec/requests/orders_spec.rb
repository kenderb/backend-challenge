# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders API", type: :request do
  let(:base_url) { "http://customer-service.test" }
  let(:api_key) { "test-internal-key" }
  let(:request_headers) do
    {
      "Host" => "www.example.com",
      "Content-Type" => "application/json"
    }
  end
  let(:valid_body) do
    {
      customer_id: 1,
      product_name: "Product #{SecureRandom.hex(4)}",
      quantity: 2,
      price: 19.99
    }
  end

  before do
    ENV["CUSTOMER_SERVICE_URL"] = base_url
    ENV["INTERNAL_API_KEY"] = api_key
    stub_request(:get, "#{base_url}/customers/1")
      .with(headers: { "X-Internal-Api-Key" => api_key })
      .to_return(
        status: 200,
        body: { name: "Jane", address: "123 Main St", orders_count: 0 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  after do
    ENV.delete("CUSTOMER_SERVICE_URL")
    ENV.delete("INTERNAL_API_KEY")
  end

  describe "POST /orders" do
    context "with valid params" do
      it "returns 201 Created and creates order and pending outbox event" do
        post orders_path, params: valid_body.to_json, headers: request_headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json).to include("id", "customer_id", "product_name", "quantity", "price", "status")
        expect(json["customer_id"]).to eq(1)
        expect(json["quantity"]).to eq(2)
        expect(json["price"]).to eq(19.99)
        expect(json["status"]).to eq("pending")
        expect(Order.count).to eq(1)
        expect(OutboxEvent.count).to eq(1)
        expect(OutboxEvent.last).to be_pending
      end

      it "returns order JSON with expected attributes" do
        post orders_path, params: valid_body.to_json, headers: request_headers

        expect(response).to have_http_status(:created)
        order = Order.last
        json = response.parsed_body
        expect(json["id"]).to eq(order.id)
        expect(json["customer_id"]).to eq(order.customer_id)
        expect(json["product_name"]).to eq(order.product_name)
        expect(json["quantity"]).to eq(order.quantity)
        expect(json["price"]).to eq(19.99)
        expect(json["status"]).to eq("pending")
        expect(json).to have_key("created_at")
      end
    end

    context "when customer does not exist" do
      before do
        stub_request(:get, "#{base_url}/customers/999")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 404)
      end

      it "returns 422 and does not create order or outbox event" do
        post orders_path, params: valid_body.merge(customer_id: 999).to_json, headers: request_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to eq("customer_not_found")
        expect(Order.count).to eq(0)
        expect(OutboxEvent.count).to eq(0)
      end
    end

    context "when customer service returns 503" do
      before do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 503)
      end

      it "returns 503 Service Unavailable and does not create order or outbox event" do
        post orders_path, params: valid_body.to_json, headers: request_headers

        expect(response).to have_http_status(:service_unavailable)
        json = response.parsed_body
        expect(json["error"]).to eq("service_unavailable")
        expect(Order.count).to eq(0)
        expect(OutboxEvent.count).to eq(0)
      end
    end

    context "with Idempotency-Key header" do
      let(:idem_key) { "idem-#{SecureRandom.uuid}" }
      let(:headers_with_idem) { request_headers.merge("Idempotency-Key" => idem_key) }

      it "returns 201 on first request and 200 with same order on duplicate key" do
        post orders_path, params: valid_body.to_json, headers: headers_with_idem
        expect(response).to have_http_status(:created)
        first_json = response.parsed_body
        first_id = first_json["id"]

        post orders_path, params: valid_body.to_json, headers: headers_with_idem
        expect(response).to have_http_status(:ok)
        second_json = response.parsed_body
        expect(second_json["id"]).to eq(first_id)
        expect(Order.count).to eq(1)
        expect(OutboxEvent.count).to eq(1)
      end
    end

    context "when concurrent requests use the same Idempotency-Key" do
      let(:idem_key) { "idem-concurrent-#{SecureRandom.uuid}" }
      let(:headers_with_idem) { request_headers.merge("Idempotency-Key" => idem_key) }
      let(:body) { valid_body.to_json }

      it "creates exactly one order and one outbox event" do
        results = []
        threads = 2.times.map do
          Thread.new do
            Rails.application.executor.wrap do
              post orders_path, params: body, headers: headers_with_idem
              results << { status: response.status }
            end
          end
        end
        threads.each(&:join)

        statuses = results.map { |r| r[:status] } # rubocop:disable Rails/Pluck -- results is Array of hashes, not Relation
        expect(statuses).to contain_exactly(201, 200)
        expect(Order.count).to eq(1)
        expect(OutboxEvent.count).to eq(1)
      end
    end
  end

  describe "GET /orders/:id" do
    let(:order) { create(:order) }

    it "returns 200 and order JSON when order exists" do
      get order_path(order), headers: request_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(order.id)
      expect(json["customer_id"]).to eq(order.customer_id)
      expect(json["product_name"]).to eq(order.product_name)
    end

    it "returns 404 when order does not exist" do
      get order_path(id: 999_999), headers: request_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
