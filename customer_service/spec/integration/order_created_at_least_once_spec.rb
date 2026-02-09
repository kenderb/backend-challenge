# frozen_string_literal: true

require "rails_helper"

# Integration test for at-least-once delivery: the same order.created event may be
# delivered more than once (e.g. broker redelivery, consumer crash after commit but before ack).
# We assert that applying the same event_id twice results in orders_count increasing only once.
RSpec.describe "Order created at-least-once idempotency" do
  let(:customer) { create(:customer, orders_count: 0) }
  let(:event_id) { "evt-at-least-once-#{SecureRandom.hex(8)}" }
  let(:payload) do
    {
      event_id: event_id,
      customer_id: customer.id,
      order_id: 999,
      product_name: "Widget",
      quantity: 1
    }
  end

  it "applying the same event_id twice increments orders_count only once" do
    expect(customer.orders_count).to eq(0)

    first = Orders::ApplyOrderCreated.call(payload)
    second = Orders::ApplyOrderCreated.call(payload)

    expect(first).to be_a(Orders::ApplyOrderCreated::Applied)
    expect(second).to be_a(Orders::ApplyOrderCreated::Skipped)
    expect(second.reason).to eq("already_processed")

    customer.reload
    expect(customer.orders_count).to eq(1)
    expect(ProcessedOrderEvent.where(event_id: event_id).count).to eq(1)
  end

  it "simulates duplicate delivery: two sequential applications with same event_id leave orders_count 1" do
    Orders::ApplyOrderCreated.call(payload)
    Orders::ApplyOrderCreated.call(payload)

    expect(customer.reload.orders_count).to eq(1)
  end
end
