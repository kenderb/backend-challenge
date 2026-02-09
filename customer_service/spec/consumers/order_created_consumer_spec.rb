# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderCreatedConsumer do
  let(:customer) { create(:customer, orders_count: 0) }
  let(:payload_hash) do
    { event_id: "evt-spec-#{SecureRandom.hex(4)}", customer_id: customer.id }
  end
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, delivery_tag: 1) }
  let(:channel) { instance_double(Bunny::Channel, ack: nil, nack: nil) }

  describe "explicit acknowledgement" do
    it "acks after ApplyOrderCreated succeeds (transaction committed)" do
      body = payload_hash.to_json

      described_class.new.send(:handle_delivery, channel, delivery_info, body)

      expect(channel).to have_received(:ack).with(1)
      expect(channel).not_to have_received(:nack)
      expect(customer.reload.orders_count).to eq(1)
    end

    it "nacks with requeue when ApplyOrderCreated raises" do
      body = payload_hash.to_json
      allow(Orders::ApplyOrderCreated).to receive(:call).and_raise(ActiveRecord::StatementInvalid.new("DB error"))

      described_class.new.send(:handle_delivery, channel, delivery_info, body)

      expect(channel).not_to have_received(:ack)
      expect(channel).to have_received(:nack).with(1, false, true)
    end
  end
end
