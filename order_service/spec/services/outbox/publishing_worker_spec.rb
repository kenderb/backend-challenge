# frozen_string_literal: true

require "rails_helper"

RSpec.describe Outbox::PublishingWorker do
  describe "when RabbitMQ broker is unavailable (network failure)" do
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
      worker = described_class.new(publisher: failing_publisher)

      expect { worker.run }.not_to raise_error

      event.reload
      expect(event.failed?).to be true
      expect(event.error_message).to be_present
      expect(OutboxEvent.pending_events.count).to eq(0)
    end

    it "keeps outbox event in a pending or failed state when broker is unreachable (event not lost)" do
      event = create(
        :outbox_event,
        event_type: "order.created",
        payload: { order_id: 1 },
        status: :pending
      )
      worker = described_class.new(publisher: failing_publisher)

      worker.run

      event.reload
      # Event must not be processed; it remains in outbox (failed so it can be retried or inspected).
      expect(event.processed?).to be false
      expect(OutboxEvent.exists?(event.id)).to be true
      expect(event.pending? || event.failed?).to be true
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
      worker = described_class.new(publisher: publisher)

      worker.run

      event.reload
      expect(event.processed?).to be true
      expect(event.processed_at).to be_present
      expect(publisher).to have_received(:publish).with(
        routing_key: "order.created",
        payload: hash_including("event_id", "order_id" => 1, "customer_id" => 1)
      )
    end
  end

  describe "FOR UPDATE SKIP LOCKED" do
    it "uses lockable_pending so only locked rows are processed" do
      create(:outbox_event, event_type: "order.created", payload: { order_id: 1 }, status: :pending)
      publisher = instance_double(Outbox::RabbitmqPublisher, publish: true)
      allow(OutboxEvent).to receive(:lockable_pending).and_call_original
      worker = described_class.new(publisher: publisher, batch_size: 10)

      worker.run

      expect(OutboxEvent).to have_received(:lockable_pending)
    end
  end
end
