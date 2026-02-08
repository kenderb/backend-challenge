# frozen_string_literal: true

module Orders
  class Create
    # @param params [Hash] order attributes (customer_id, product_name, quantity, price, etc.)
    # @param idempotency_key [String, nil] optional key to prevent duplicate orders on retries
    # @param event_publisher [Object, nil] optional callable to emit events (e.g. RabbitMQ) after success
    # @return [Order] the created or existing order
    # @raise [ActiveRecord::RecordInvalid] when params are invalid
    def self.call(params, idempotency_key: nil, event_publisher: nil)
      new(params: params, idempotency_key: idempotency_key, event_publisher: event_publisher).call
    end

    def initialize(params:, idempotency_key: nil, event_publisher: nil)
      @params = params.to_h.with_indifferent_access
      @idempotency_key = idempotency_key.presence
      @event_publisher = event_publisher
    end

    def call
      return existing_order if idempotency_key && existing_order

      create_order
    end

    private

    attr_reader :params, :idempotency_key, :event_publisher

    def existing_order
      @existing_order ||= IdempotencyKey.find_by(key: idempotency_key)&.order
    end

    def create_order
      if idempotency_key
        create_order_with_idempotency
      else
        order = Order.create!(order_params)
        publish_order_created(order) if event_publisher
        order
      end
    end

    def create_order_with_idempotency
      Order.transaction do
        order = Order.create!(order_params)
        IdempotencyKey.create!(key: idempotency_key, order: order)
        publish_order_created(order) if event_publisher
        order
      end
    rescue ActiveRecord::RecordNotUnique
      IdempotencyKey.find_by!(key: idempotency_key).order
    end

    def order_params
      params.slice(:customer_id, :product_name, :quantity, :price, :status).compact
    end

    def publish_order_created(order)
      return unless event_publisher.respond_to?(:call)

      event_publisher.call(:order_created, order)
    end
  end
end
