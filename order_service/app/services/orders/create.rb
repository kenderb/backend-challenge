# frozen_string_literal: true

module Orders
  # Creates an order using the transactional outbox pattern: order and outbox event
  # are persisted atomically. Event delivery is performed by Outbox::Relay (Rake or worker).
  class Create
    Success = Struct.new(:value, keyword_init: true) do
      def success? = true
      def failure? = false
      def error_code = nil
      def message = nil
    end
    Failure = Struct.new(:error_code, :message, keyword_init: true) do
      def success? = false
      def failure? = true
      def value = nil
    end

    # @param params [Hash] order attributes (customer_id, product_name, quantity, price, etc.)
    # @param idempotency_key [String, nil] optional key to prevent duplicate orders on retries
    # @param event_publisher [Object, nil] deprecated; ignored. Events are published via outbox relay.
    # @return [Success, Failure] Success(order) or Failure(:customer_not_found | :unauthorized |
    #   :service_unavailable, message)
    def self.call(params, idempotency_key: nil, event_publisher: nil, customer_client: nil) # rubocop:disable Lint/UnusedMethodArgument
      CreateWithOutbox.call(
        params,
        idempotency_key: idempotency_key,
        customer_client: customer_client
      )
    end
  end
end
