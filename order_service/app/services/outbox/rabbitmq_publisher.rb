# frozen_string_literal: true

module Outbox
  # Publishes messages to RabbitMQ (exchange: orders.v1). Uses RABBITMQ_HOST from docker-compose.
  # Retries with exponential backoff when the broker is unreachable.
  class RabbitmqPublisher
    ORDERS_EXCHANGE = "orders.v1"
    ROUTING_KEY_ORDER_CREATED = "order.created"

    DEFAULT_MAX_ATTEMPTS = 5
    DEFAULT_BASE_DELAY_SECONDS = 1

    def initialize(connection_params: nil, max_attempts: DEFAULT_MAX_ATTEMPTS, base_delay: DEFAULT_BASE_DELAY_SECONDS)
      @connection_params = connection_params || default_connection_params
      @max_attempts = max_attempts
      @base_delay = base_delay
    end

    # Publishes payload to exchange with given routing_key. Returns true on success.
    # Retries with exponential backoff on connection/publish errors; raises after max_attempts.
    def publish(routing_key:, payload:)
      with_retries { connect_and_publish(routing_key, payload) }
    end

    private

    def with_retries # rubocop:disable Metrics/MethodLength
      attempt = 0
      begin
        attempt += 1
        yield
        true
      rescue StandardError => e
        raise e if attempt >= @max_attempts

        sleep_backoff(attempt)
        retry
      ensure
        connection&.close
        @connection = nil
      end
    end

    def sleep_backoff(attempt)
      sleep(@base_delay * (2**(attempt - 1)))
    end

    def connect_and_publish(routing_key, payload)
      connection.start
      with_channel { |ch| publish_to_exchange(ch, routing_key, payload) }
    end

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
