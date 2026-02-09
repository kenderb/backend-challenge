# frozen_string_literal: true

require "rails_helper"

RSpec.describe OutboxEvent do
  describe "validations" do
    it "validates presence of aggregate_type" do
      event = build(:outbox_event, aggregate_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:aggregate_type]).to include("can't be blank")
    end

    it "validates presence of aggregate_id" do
      event = build(:outbox_event, aggregate_id: nil)
      expect(event).not_to be_valid
      expect(event.errors[:aggregate_id]).to include("can't be blank")
    end

    it "validates presence of event_type" do
      event = build(:outbox_event, event_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to include("can't be blank")
    end

    it "validates presence of payload" do
      event = build(:outbox_event, payload: nil)
      expect(event).not_to be_valid
      expect(event.errors[:payload]).to include("can't be blank")
    end

    it "validates status is a valid enum value" do
      event = build(:outbox_event, status: 99)
      expect(event).not_to be_valid
      expect(event.errors[:status]).to be_present
    end
  end

  describe "defaults" do
    it "defaults status to pending" do
      event = described_class.new(
        aggregate_type: "Order",
        aggregate_id: "1",
        event_type: "order.created",
        payload: {}
      )
      event.valid?
      expect(event.status).to eq("pending")
    end
  end

  describe "state transitions" do
    let(:event) do
      create(
        :outbox_event,
        aggregate_type: "Order",
        aggregate_id: "1",
        event_type: "order.created",
        payload: { order_id: 1, customer_id: 1 },
        status: :pending
      )
    end

    it "transitions from pending to processing with mark_processing!" do
      expect(event.pending?).to be true
      event.mark_processing!
      expect(event.reload.processing?).to be true
    end

    it "transitions from processing to processed with mark_processed!" do
      event.mark_processing!
      event.mark_processed!
      event.reload
      expect(event.processed?).to be true
      expect(event.processed_at).to be_present
      expect(event.error_message).to be_nil
    end

    it "transitions from pending to failed with mark_failed!" do
      error_msg = "Connection refused"
      event.mark_failed!(error_msg)
      event.reload
      expect(event.failed?).to be true
      expect(event.error_message).to eq(error_msg)
    end

    it "can transition processing -> failed when publish fails" do
      event.mark_processing!
      event.mark_failed!("Broker unavailable")
      event.reload
      expect(event.failed?).to be true
      expect(event.error_message).to eq("Broker unavailable")
    end
  end

  describe "scopes" do
    before do
      create(:outbox_event, status: :pending)
      create(:outbox_event, status: :pending)
      create(:outbox_event, status: :processed)
      create(:outbox_event, status: :failed)
    end

    it "pending_events returns only pending in created_at order" do
      pending = described_class.pending_events
      expect(pending.count).to eq(2)
      expect(pending.pluck(:status).uniq).to eq(["pending"])
    end

    it "processed_events returns only processed" do
      expect(described_class.processed_events.count).to eq(1)
    end
  end
end
