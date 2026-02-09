# frozen_string_literal: true

module Outbox
  # Fetches unprocessed outbox events, publishes to RabbitMQ, and marks them processed
  # only after successful publish (broker ACK). Run via Rake or a scheduler.
  class Relay
    EVENT_ROUTING_KEYS = {
      "order.created" => "order.created"
    }.freeze

    def initialize(publisher: nil, batch_size: 100)
      @publisher = publisher || RabbitmqPublisher.new
      @batch_size = batch_size
    end

    def run
      processed = 0
      OutboxEvent.pending_events.limit(@batch_size).find_each do |event|
        process_event(event)
        processed += 1
      end
      processed
    end

    private

    def process_event(event)
      event.mark_processing!
      routing_key = EVENT_ROUTING_KEYS[event.event_type] || event.event_type.tr("_", ".")
      payload = build_payload(event)
      @publisher.publish(routing_key: routing_key, payload: payload)
      event.mark_processed!
    rescue StandardError => e
      event.mark_failed!(e.message)
      # Do not re-raise so other events in the batch can be processed
    end

    def build_payload(event)
      event.payload.merge(
        "event_id" => event.id.to_s,
        "occurred_at" => event.created_at.iso8601(3)
      )
    end
  end
end
