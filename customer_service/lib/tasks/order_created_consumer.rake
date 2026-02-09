# frozen_string_literal: true

namespace :consumer do
  desc "Run the order.created RabbitMQ consumer (blocking). Acks only after DB commit; nacks on failure."
  task order_created: :environment do
    OrderCreatedConsumer.new.run
  end
end
