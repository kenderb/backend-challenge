# frozen_string_literal: true

module Orders
  # Applies an order.created event idempotently: increments customer.orders_count
  # only once per event_id. Safe to call multiple times with the same event (e.g. duplicate delivery).
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

      return Skipped.new(reason: "already_processed") if ProcessedOrderEvent.exists?(event_id: event_id)

      customer = Customer.find_by(id: customer_id)
      return Skipped.new(reason: "customer_not_found") unless customer

      apply_event(customer, event_id)
    end

    private

    def apply_event(customer, event_id)
      ActiveRecord::Base.transaction do
        ProcessedOrderEvent.create!(event_id: event_id, customer_id: customer.id)
        customer.increment!(:orders_count) # rubocop:disable Rails/SkipsModelValidations -- counter cache, no validations needed
        Applied.new(customer: customer.reload, processed_event: ProcessedOrderEvent.find_by!(event_id: event_id))
      end
    rescue ActiveRecord::RecordNotUnique
      Skipped.new(reason: "already_processed")
    end
  end
end
