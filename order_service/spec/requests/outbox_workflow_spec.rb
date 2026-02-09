# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Outbox workflow (full-flow integration)", type: :request do
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
      product_name: "Workflow Product #{SecureRandom.hex(4)}",
      quantity: 1,
      price: 10.0
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

  describe "full-flow: API → outbox → worker → published" do
    it "creates order via POST, then worker publishes pending event and marks it processed" do
      post api_v1_orders_path, params: valid_body.to_json, headers: request_headers
      expect(response).to have_http_status(:created)

      order_id = response.parsed_body["id"]
      expect(OutboxEvent.pending_events.count).to eq(1)
      event = OutboxEvent.pending_events.last
      expect(event.event_type).to eq("order.created")
      expect(event.payload["order_id"]).to eq(order_id)

      published = []
      publisher = instance_double(Outbox::RabbitmqPublisher).tap do |dbl|
        allow(dbl).to receive(:publish) do |routing_key:, payload:|
          published << { routing_key: routing_key, payload: payload }
          true
        end
      end
      worker = Outbox::PublishingWorker.new(publisher: publisher)

      processed = worker.run

      expect(processed).to eq(1)
      event.reload
      expect(event).to be_processed
      expect(published.size).to eq(1)
      expect(published.first[:routing_key]).to eq("order.created")
      expect(published.first[:payload]).to include("event_id", "occurred_at")
      expect(published.first[:payload]["order_id"]).to eq(order_id)
    end
  end

  describe "worker retry: first publish fails, retry (event reset to pending) then succeeds" do
    it "marks event failed on first run, then processed after reset to pending and second run" do
      post api_v1_orders_path, params: valid_body.to_json, headers: request_headers
      expect(response).to have_http_status(:created)
      expect(OutboxEvent.pending_events.count).to eq(1)
      event = OutboxEvent.pending_events.last

      call_count = 0
      publisher = instance_double(Outbox::RabbitmqPublisher).tap do |dbl|
        allow(dbl).to receive(:publish) do
          call_count += 1
          raise "Broker unavailable" if call_count == 1

          true
        end
      end
      worker = Outbox::PublishingWorker.new(publisher: publisher)

      worker.run
      event.reload
      expect(event).to be_failed
      expect(event.error_message).to be_present

      event.update!(status: :pending, error_message: nil)
      worker.run
      event.reload
      expect(event).to be_processed
      expect(call_count).to eq(2)
    end
  end

  describe "worker batch: multiple pending events in one run" do
    it "processes all pending events in a single worker run" do
      post api_v1_orders_path, params: valid_body.to_json, headers: request_headers
      expect(response).to have_http_status(:created)
      body2 = valid_body.merge(product_name: "Workflow Product #{SecureRandom.hex(4)}")
      post api_v1_orders_path, params: body2.to_json, headers: request_headers
      expect(response).to have_http_status(:created)

      expect(OutboxEvent.pending_events.count).to eq(2)

      published = []
      publisher = instance_double(Outbox::RabbitmqPublisher).tap do |dbl|
        allow(dbl).to receive(:publish) do |routing_key:, payload:|
          expect(routing_key).to eq("order.created")
          published << payload
          true
        end
      end
      worker = Outbox::PublishingWorker.new(publisher: publisher)

      processed = worker.run

      expect(processed).to eq(2)
      expect(published.size).to eq(2)
      expect(OutboxEvent.processed_events.count).to eq(2)
    end
  end

  describe "worker empty: no pending events" do
    it "processes nothing and returns 0 without calling publisher" do
      publisher = instance_double(Outbox::RabbitmqPublisher)
      allow(publisher).to receive(:publish)
      worker = Outbox::PublishingWorker.new(publisher: publisher)

      processed = worker.run

      expect(processed).to eq(0)
      expect(publisher).not_to have_received(:publish)
    end
  end
end
