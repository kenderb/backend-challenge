# frozen_string_literal: true

module Orders
  # Applies an order.created event idempotently: increments customer.orders_count
  # only once per event_id. Safe to call multiple times with the same event (at-least-once delivery).
  # Atomic: ProcessedOrderEvent insert and Customer.orders_count update run in a single transaction.
  # Uses Customer.increment_counter for race-safe update in multi-threaded consumers.
  class ApplyOrderCreated
    # @param payload [Hash] must include :event_id, :customer_id (and optionally order_id, etc.)
    # @return [Applied, Skipped] Applied when count was incremented, Skipped when already processed
    def self.call(payload)
      new(payload).call
    end

    Applied = Struct.new(:customer, :processed_event, keyword_init: true)
    Skipped = Struct.new(:reason, keyword_init: true) do
      def applied? = false
    end

    def initialize(payload)
      @payload = payload.to_h.with_indifferent_access
    end

    def call
      event_id = @payload[:event_id]
      customer_id = @payload[:customer_id]
      return Skipped.new(reason: "missing event_id") if event_id.blank?
      return Skipped.new(reason: "missing customer_id") if customer_id.blank?

      customer = Customer.find_by(id: customer_id)
      return Skipped.new(reason: "customer_not_found") unless customer

      apply_event_atomically(customer, event_id)
    end

    private

    # Single transaction: insert ProcessedOrderEvent (unique constraint enforces idempotency),
    # then atomic increment. On RecordNotUnique we skip without incrementing.
    def apply_event_atomically(customer, event_id)
      ActiveRecord::Base.transaction do
        ProcessedOrderEvent.create!(event_id: event_id, customer_id: customer.id)
        Customer.increment_counter(:orders_count, customer.id) # rubocop:disable Rails/SkipsModelValidations -- atomic counter, no validations
        processed = ProcessedOrderEvent.find_by!(event_id: event_id)
        Applied.new(customer: Customer.find(customer.id), processed_event: processed)
      end
    rescue ActiveRecord::RecordNotUnique
      Skipped.new(reason: "already_processed")
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(ProcessedOrderEvent) && e.record.errors[:event_id].present?
        return Skipped.new(reason: "already_processed")
      end

      raise
    end
  end
end
