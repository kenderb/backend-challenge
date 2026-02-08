# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order, type: :model do
  describe "defaults" do
    it "defaults quantity to 0" do
      order = described_class.new(
        customer_id: 1,
        product_name: "Test Product",
        price: 10.00
      )
      expect(order.quantity).to eq(0)
    end
  end

  describe "validations" do
    subject { build(:order) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:customer_id) }
    it { is_expected.to validate_presence_of(:product_name) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_uniqueness_of(:product_name) }
  end

  describe "enum status" do
    it "defines status enum with pending, processing, completed, and cancelled" do
      expect(described_class.statuses).to eq(
        "pending" => 0,
        "processing" => 1,
        "completed" => 2,
        "cancelled" => 3
      )
    end

    it "defaults to pending" do
      order = described_class.new(
        customer_id: 1,
        product_name: "Product",
        price: 5.00
      )
      expect(order.status).to eq("pending")
    end

    it "can be set to processing, completed, and cancelled" do
      order = build(:order)
      order.processing!
      expect(order.status).to eq("processing")
      order.completed!
      expect(order.status).to eq("completed")
      order.cancelled!
      expect(order.status).to eq("cancelled")
    end
  end
end
