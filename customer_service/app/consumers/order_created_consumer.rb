# frozen_string_literal: true

# Consumes order.created events from RabbitMQ (exchange: orders.v1, routing_key: order.created).
# Applies events idempotently via Orders::ApplyOrderCreated. Acks only after DB transaction commits;
# nacks on failure to allow retries.
class OrderCreatedConsumer
  ORDERS_EXCHANGE = "orders.v1"
  ROUTING_KEY = "order.created"
  QUEUE_NAME = "customer_service.order.created"

  def initialize(connection_params: nil)
    @connection_params = connection_params || default_connection_params
  end

  def run
    conn = Bunny.new(@connection_params)
    conn.start
    ch = conn.create_channel
    ch.prefetch(1)
    exchange = ch.topic(ORDERS_EXCHANGE, durable: true)
    queue = ch.queue(QUEUE_NAME, durable: true)
    queue.bind(exchange, routing_key: ROUTING_KEY)

    queue.subscribe(manual_ack: true, block: true) do |delivery_info, _properties, body|
      handle_delivery(ch, delivery_info, body)
    end
  ensure
    ch&.close
    conn&.close
  end

  private

  def handle_delivery(channel, delivery_info, body)
    payload = parse_payload(body)
    Orders::ApplyOrderCreated.call(payload)
    channel.ack(delivery_info.delivery_tag)
  rescue StandardError => e
    Rails.logger.error("[OrderCreatedConsumer] Failed to process: #{e.message}")
    channel.nack(delivery_info.delivery_tag, false, true)
  end

  def parse_payload(body)
    JSON.parse(body.to_s).transform_keys(&:to_sym)
  rescue JSON::ParserError => e
    Rails.logger.error("[OrderCreatedConsumer] Invalid JSON: #{e.message}")
    raise
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
