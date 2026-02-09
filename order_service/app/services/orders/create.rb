# frozen_string_literal: true

module Orders
  # Creates an order using the transactional outbox pattern; delegates to CreateOrder.
  # Event delivery is performed by Outbox::PublishingWorker.
  class Create
    # @param params [Hash] order attributes (customer_id, product_name, quantity, price, etc.)
    # @param idempotency_key [String, nil] optional key to prevent duplicate orders on retries
    # @param event_publisher [Object, nil] deprecated; ignored. Events are published via outbox worker.
    # @return [Result::Success, Result::Failure] Success(order) or Failure(:customer_not_found | :unauthorized |
    #   :service_unavailable, message)
    def self.call(params, idempotency_key: nil, event_publisher: nil, customer_client: nil) # rubocop:disable Lint/UnusedMethodArgument
      CreateOrder.call(
        params,
        idempotency_key: idempotency_key,
        customer_client: customer_client
      )
    end
  end
end
