# frozen_string_literal: true

module Orders
  class Create
    # Structured result: success with order, or failure with error_code and message.
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
    # @param event_publisher [Object, nil] optional callable to emit events (e.g. RabbitMQ) after success
    # @return [Success, Failure] Success(order) or Failure(:customer_not_found | :service_unavailable, message)
    # @raise [ActiveRecord::RecordInvalid] when params are invalid (e.g. missing required fields)
    def self.call(params, idempotency_key: nil, event_publisher: nil, customer_client: nil)
      new(
        params: params,
        idempotency_key: idempotency_key,
        event_publisher: event_publisher,
        customer_client: customer_client
      ).call
    end

    def initialize(params:, idempotency_key: nil, event_publisher: nil, customer_client: nil)
      @params = params.to_h.with_indifferent_access
      @idempotency_key = idempotency_key.presence
      @event_publisher = event_publisher
      @customer_client = customer_client || ExternalApis::CustomerClient.new
    end

    def call
      return Success.new(value: existing_order) if idempotency_key && existing_order

      validate_customer!
      Success.new(value: create_order)
    rescue Errors::CustomerNotFound => e
      Failure.new(error_code: :customer_not_found, message: e.message)
    rescue Errors::CustomerServiceUnavailable, Errors::ServiceUnavailable => e
      Failure.new(error_code: :service_unavailable, message: e.message)
    end

    private

    attr_reader :params, :idempotency_key, :event_publisher, :customer_client

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

    def validate_customer!
      return if params[:customer_id].blank?

      customer_client.fetch_customer(params[:customer_id])
    end
  end
end
