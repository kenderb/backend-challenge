# frozen_string_literal: true

module Orders
  # Creates an Order and a corresponding OutboxEvent in a single ActiveRecord transaction,
  # ensuring atomicity between business state and event storage (transactional outbox).
  # Event delivery is performed by Outbox::PublishingWorker; this service does not publish to RabbitMQ.
  class CreateOrder
    ORDER_AGGREGATE_TYPE = "Order"
    ORDER_CREATED_EVENT_TYPE = "order.created"

    def self.call(params, idempotency_key: nil, customer_client: nil)
      new(
        params: params,
        idempotency_key: idempotency_key,
        customer_client: customer_client
      ).call
    end

    def initialize(params:, idempotency_key: nil, customer_client: nil)
      @params = params.to_h.with_indifferent_access
      @idempotency_key = idempotency_key.presence
      @customer_client = customer_client || ExternalApis::CustomerClient.new
    end

    def call
      return Result::Success.new(value: existing_order) if idempotency_key && existing_order

      validate_customer!
      Result::Success.new(value: create_order_and_outbox_event)
    rescue Errors::CustomerNotFound => e
      Result::Failure.new(error_code: :customer_not_found, message: e.message)
    rescue Errors::UnauthorizedError => e
      Result::Failure.new(error_code: :unauthorized, message: e.message)
    rescue Errors::CustomerServiceUnavailable, Errors::ServiceUnavailable => e
      Result::Failure.new(error_code: :service_unavailable, message: e.message)
    end

    private

    attr_reader :params, :idempotency_key, :customer_client

    def existing_order
      @existing_order ||= IdempotencyKey.find_by(key: idempotency_key)&.order
    end

    def create_order_and_outbox_event
      if idempotency_key
        create_order_and_outbox_with_idempotency
      else
        create_order_and_outbox_without_idempotency
      end
    rescue ActiveRecord::RecordNotUnique
      IdempotencyKey.find_by!(key: idempotency_key).order
    end

    def create_order_and_outbox_without_idempotency
      ActiveRecord::Base.transaction do
        order = Order.create!(order_params)
        OutboxEvent.create!(outbox_attrs_for_order(order))
        order
      end
    end

    def create_order_and_outbox_with_idempotency
      ActiveRecord::Base.transaction do
        order = Order.create!(order_params)
        IdempotencyKey.create!(key: idempotency_key, order: order)
        OutboxEvent.create!(outbox_attrs_for_order(order))
        order
      end
    end

    def outbox_attrs_for_order(order)
      {
        aggregate_type: ORDER_AGGREGATE_TYPE,
        aggregate_id: order.id.to_s,
        event_type: ORDER_CREATED_EVENT_TYPE,
        payload: order_created_payload(order),
        status: :pending
      }
    end

    def order_created_payload(order)
      {
        order_id: order.id,
        customer_id: order.customer_id,
        product_name: order.product_name,
        quantity: order.quantity,
        price: order.price.to_f,
        status: order.status
      }
    end

    def order_params
      params.slice(:customer_id, :product_name, :quantity, :price, :status).compact
    end

    def validate_customer!
      return if params[:customer_id].blank?

      customer_client.fetch_customer(params[:customer_id])
    end
  end
end
