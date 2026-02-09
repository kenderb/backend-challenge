# frozen_string_literal: true

module Outbox
  # Publishes messages to RabbitMQ (exchange: orders.v1, routing_key: order.created).
  # Used by the outbox relay after successfully reading from the outbox table.
  class RabbitmqPublisher
    ORDERS_EXCHANGE = "orders.v1"
    ROUTING_KEY_ORDER_CREATED = "order.created"

    def initialize(connection_params: nil)
      @connection_params = connection_params || default_connection_params
    end

    # Publishes payload to exchange with given routing_key. Returns true on success.
    # Raises on connection/publish errors so the relay can retry later.
    def publish(routing_key:, payload:)
      connection.start
      with_channel { |ch| publish_to_exchange(ch, routing_key, payload) }
      true
    ensure
      connection.close
    end

    private

    def publish_to_exchange(channel, routing_key, payload)
      exchange = channel.topic(ORDERS_EXCHANGE, durable: true)
      exchange.publish(
        payload.to_json,
        routing_key: routing_key,
        persistent: true,
        content_type: "application/json"
      )
    end

    def with_channel
      channel = connection.create_channel
      yield channel
    ensure
      channel&.close
    end

    def connection
      @connection ||= Bunny.new(@connection_params)
    end

    def default_connection_params
      {
        host: ENV.fetch("RABBITMQ_HOST", "localhost"),
        port: ENV.fetch("RABBITMQ_PORT", "5672").to_i,
        user: ENV.fetch("RABBITMQ_USER", "guest"),
        password: ENV.fetch("RABBITMQ_PASSWORD", "guest"),
        automatically_recover: true
      }
    end
  end
end
