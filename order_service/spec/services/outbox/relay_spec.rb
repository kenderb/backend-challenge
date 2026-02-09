# frozen_string_literal: true

require "rails_helper"

RSpec.describe Outbox::Relay do
  describe "when RabbitMQ broker is unavailable" do
    let(:failing_publisher) do
      instance_double(Outbox::RabbitmqPublisher).tap do |dbl|
        allow(dbl).to receive(:publish).and_raise(Bunny::TCPConnectionFailedForAllHosts)
      end
    end

    it "marks the event as failed and does not lose the event (stays in outbox)" do
      event = create(
        :outbox_event,
        event_type: "order.created",
        payload: { order_id: 1, customer_id: 1 },
        status: :pending
      )
      relay = described_class.new(publisher: failing_publisher)

      expect { relay.run }.not_to raise_error

      event.reload
      expect(event.failed?).to be true
      expect(event.error_message).to be_present
      expect(OutboxEvent.pending_events.count).to eq(0)
    end
  end

  describe "when publish succeeds" do
    let(:publisher) do
      instance_double(Outbox::RabbitmqPublisher).tap do |dbl|
        allow(dbl).to receive(:publish).and_return(true)
      end
    end

    it "marks the event as processed after successful publish" do
      event = create(
        :outbox_event,
        event_type: "order.created",
        payload: { order_id: 1, customer_id: 1 },
        status: :pending
      )
      relay = described_class.new(publisher: publisher)

      relay.run

      event.reload
      expect(event.processed?).to be true
      expect(event.processed_at).to be_present
      expect(publisher).to have_received(:publish).with(
        routing_key: "order.created",
        payload: hash_including("event_id", "order_id" => 1, "customer_id" => 1)
      )
    end
  end
end
