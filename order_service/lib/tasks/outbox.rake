# frozen_string_literal: true

namespace :outbox do
  desc "Process pending outbox events: publish to RabbitMQ and mark processed (run once)"
  task relay_once: :environment do
    count = Outbox::Relay.new.run
    puts "Processed #{count} outbox event(s)."
  end

  desc "Poll outbox and relay events every INTERVAL seconds (default: 5). Stop with Ctrl+C."
  task :relay, [:interval_seconds] => :environment do |_t, args|
    interval = (args[:interval_seconds] || 5).to_i
    interval = 1 if interval < 1
    puts "Outbox relay started (interval=#{interval}s). Press Ctrl+C to stop."
    loop do
      count = Outbox::Relay.new.run
      puts "[#{Time.current.iso8601}] Processed #{count} event(s)." if count.positive?
      sleep interval
    end
  end
end
