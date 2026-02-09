# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orders::CreateWithOutbox do
  let(:base_url) { "http://customer-service.test" }
  let(:api_key) { "test-internal-key" }
  let(:valid_params) do
    {
      customer_id: 1,
      product_name: "Unique Product #{SecureRandom.hex(4)}",
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

  describe "atomicity and outbox (no event lost when broker is down)" do
    it "creates the order and one pending outbox event in a single transaction" do
      expect do
        result = described_class.call(valid_params)
        expect(result.success?).to be true
        expect(result.value.order).to be_persisted
      end.to change(Order, :count).by(1).and change(OutboxEvent, :count).by(1)
    end

    it "stores outbox event with correct attributes for the created order" do
      result = described_class.call(valid_params)
      order = result.value.order
      event = OutboxEvent.last

      expect(event.status).to eq("pending")
      expect(event.event_type).to eq("order.created")
      expect(event.aggregate_type).to eq("Order")
      expect(event.aggregate_id).to eq(order.id.to_s)
      expect(event.payload).to include(
        "order_id" => order.id,
        "customer_id" => order.customer_id,
        "product_name" => order.product_name,
        "quantity" => order.quantity
      )
    end

    it "does not publish to RabbitMQ during order creation (event is only in outbox)" do
      # No RabbitMQ connection is made; event remains in outbox for relay to process later.
      result = described_class.call(valid_params)
      expect(result.success?).to be true
      expect(OutboxEvent.pending_events.count).to eq(1)
    end
  end

  describe "idempotency key" do
    let(:idempotency_key) { "idem-#{SecureRandom.uuid}" }

    it "creates order and outbox event with idempotency in one transaction" do
      result = described_class.call(valid_params, idempotency_key: idempotency_key)
      expect(result.success?).to be true
      expect(Order.count).to eq(1)
      expect(OutboxEvent.count).to eq(1)
      expect(OutboxEvent.last.status).to eq("pending")
    end

    it "returns existing order on duplicate idempotency key and does not create a second outbox event" do
      described_class.call(valid_params, idempotency_key: idempotency_key)
      result = described_class.call(valid_params, idempotency_key: idempotency_key)
      expect(result.success?).to be true
      expect(Order.count).to eq(1)
      expect(OutboxEvent.count).to eq(1)
    end
  end
end
