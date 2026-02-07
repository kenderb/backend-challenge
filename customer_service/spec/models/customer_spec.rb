# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer, type: :model do
  describe "defaults" do
    it "defaults orders_count to 0" do
      customer = described_class.new(name: "Jane", address: "123 St")
      expect(customer.orders_count).to eq(0)
    end
  end

  describe "validations" do
    subject { build(:customer) }

    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_numericality_of(:orders_count).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "name" do
    it "is invalid when blank" do
      customer = build(:customer, name: nil)
      expect(customer).not_to be_valid
      expect(customer.errors[:name]).to include("can't be blank")
    end

    it "is invalid when empty string" do
      customer = build(:customer, name: "   ")
      expect(customer).not_to be_valid
      expect(customer.errors[:name]).to include("can't be blank")
    end

    it "must be unique (case insensitive)" do
      create(:customer, name: "Alice Smith")
      duplicate = build(:customer, name: "alice smith")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "address" do
    it "is invalid when blank" do
      customer = build(:customer, address: nil)
      expect(customer).not_to be_valid
      expect(customer.errors[:address]).to include("can't be blank")
    end

    it "is invalid when empty string" do
      customer = build(:customer, address: "   ")
      expect(customer).not_to be_valid
      expect(customer.errors[:address]).to include("can't be blank")
    end
  end

  describe "orders_count" do
    it "is invalid when negative" do
      customer = build(:customer, orders_count: -1)
      expect(customer).not_to be_valid
      expect(customer.errors[:orders_count]).to include("must be greater than or equal to 0")
    end

    it "is invalid when not an integer" do
      customer = build(:customer, orders_count: 1.5)
      expect(customer).not_to be_valid
      expect(customer.errors[:orders_count]).to include("must be an integer")
    end

    it "is valid when zero" do
      customer = build(:customer, orders_count: 0)
      expect(customer).to be_valid
    end
  end
end
