# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orders::Create do
  describe ".call" do
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

    context "with valid params" do
      it "creates an order successfully" do
        expect do
          described_class.call(valid_params)
        end.to change(Order, :count).by(1)
      end

      it "returns a persisted Order" do
        order = described_class.call(valid_params)

        expect(order).to be_a(Order)
        expect(order).to be_persisted
      end

      it "returns the order with the given attributes and pending status" do
        order = described_class.call(valid_params)

        expect(order.customer_id).to eq(valid_params[:customer_id])
        expect(order.product_name).to eq(valid_params[:product_name])
        expect(order.quantity).to eq(valid_params[:quantity])
        expect(order.price).to eq(valid_params[:price])
        expect(order.status).to eq("pending")
      end
    end

    context "when customer_id is nil" do
      it "raises an error" do
        invalid_params = valid_params.merge(customer_id: nil)

        expect do
          described_class.call(invalid_params)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when customer is not found" do
      it "raises Errors::CustomerNotFound and does not create an order" do
        stub_request(:get, "#{base_url}/customers/999")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 404)

        initial_count = Order.count
        expect do
          described_class.call(valid_params.merge(customer_id: 999))
        end.to raise_error(Errors::CustomerNotFound)
        expect(Order.count).to eq(initial_count)
      end
    end

    context "when customer service is unavailable" do
      it "raises Errors::ServiceUnavailable and does not create an order" do
        stub_request(:get, "#{base_url}/customers/1")
          .with(headers: { "X-Internal-Api-Key" => api_key })
          .to_return(status: 503)

        initial_count = Order.count
        expect do
          described_class.call(valid_params)
        end.to raise_error(Errors::ServiceUnavailable)
        expect(Order.count).to eq(initial_count)
      end
    end

    context "with idempotency key" do
      let(:idempotency_key) { "idem-#{SecureRandom.uuid}" }

      it "creates an order on first request and stores the key" do
        order = described_class.call(valid_params, idempotency_key: idempotency_key)

        expect(order).to be_persisted
        expect(IdempotencyKey.find_by(key: idempotency_key).order_id).to eq(order.id)
      end

      it "returns the existing order on duplicate key and does not increment count" do
        order_first = described_class.call(valid_params, idempotency_key: idempotency_key)
        order_second = described_class.call(valid_params, idempotency_key: idempotency_key)

        expect(order_second.id).to eq(order_first.id)
        expect(order_second).to eq(order_first)
        expect(Order.count).to eq(1)
      end

      it "does not create a second IdempotencyKey record for the same key" do
        described_class.call(valid_params, idempotency_key: idempotency_key)
        described_class.call(valid_params, idempotency_key: idempotency_key)

        expect(IdempotencyKey.where(key: idempotency_key).count).to eq(1)
      end
    end
  end
end
