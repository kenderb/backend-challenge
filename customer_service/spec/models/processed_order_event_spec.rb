# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessedOrderEvent, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:customer) }
  end

  describe "validations" do
    subject { build(:processed_order_event) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_uniqueness_of(:event_id) }
  end

  describe "event_id" do
    it "is invalid when blank" do
      record = build(:processed_order_event, event_id: nil)
      expect(record).not_to be_valid
      expect(record.errors[:event_id]).to include("can't be blank")
    end

    it "is invalid when empty string" do
      record = build(:processed_order_event, event_id: "   ")
      expect(record).not_to be_valid
      expect(record.errors[:event_id]).to include("can't be blank")
    end

    it "must be unique" do
      create(:processed_order_event, event_id: "evt-unique-123")
      duplicate = build(:processed_order_event, event_id: "evt-unique-123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:event_id]).to include("has already been taken")
    end
  end
end
