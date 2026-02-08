# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyKey, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:order) }
  end

  describe "validations" do
    subject { build(:idempotency_key) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
  end

  describe "key" do
    it "is invalid when blank" do
      idempotency_key = build(:idempotency_key, key: nil)
      expect(idempotency_key).not_to be_valid
      expect(idempotency_key.errors[:key]).to include("can't be blank")
    end

    it "must be unique" do
      create(:idempotency_key, key: "unique-key-123")
      duplicate = build(:idempotency_key, key: "unique-key-123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end
  end
end
