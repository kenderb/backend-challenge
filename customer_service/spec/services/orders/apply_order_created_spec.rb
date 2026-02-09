# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orders::ApplyOrderCreated do
  let(:customer) { create(:customer, orders_count: 0) }

  describe "idempotency" do
    let(:payload) do
      { event_id: "evt-123", customer_id: customer.id, order_id: 999 }
    end

    it "increments customer orders_count on first application" do
      result = described_class.call(payload)

      expect(result).to be_a(Orders::ApplyOrderCreated::Applied)
      expect(result.customer.orders_count).to eq(1)
      expect(ProcessedOrderEvent.exists?(event_id: "evt-123")).to be true
    end

    it "does not increment again when same event_id is applied (duplicate delivery)" do
      described_class.call(payload)
      result_second = described_class.call(payload)

      expect(result_second).to be_a(Orders::ApplyOrderCreated::Skipped)
      expect(result_second.reason).to eq("already_processed")
      expect(customer.reload.orders_count).to eq(1)
    end
  end

  describe "validation" do
    it "skips when event_id is missing" do
      result = described_class.call(customer_id: customer.id)
      expect(result).to be_a(Orders::ApplyOrderCreated::Skipped)
      expect(result.reason).to eq("missing event_id")
      expect(customer.reload.orders_count).to eq(0)
    end

    it "skips when customer_id is missing" do
      result = described_class.call(event_id: "evt-1")
      expect(result).to be_a(Orders::ApplyOrderCreated::Skipped)
      expect(result.reason).to eq("missing customer_id")
    end

    it "skips when customer does not exist" do
      result = described_class.call(event_id: "evt-1", customer_id: 999_999)
      expect(result).to be_a(Orders::ApplyOrderCreated::Skipped)
      expect(result.reason).to eq("customer_not_found")
    end
  end
end
