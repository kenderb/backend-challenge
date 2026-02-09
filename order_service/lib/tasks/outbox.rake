# frozen_string_literal: true

namespace :outbox do
  desc "Process pending outbox events once (FOR UPDATE SKIP LOCKED). Use from PublishingWorker."
  task publish_once: :environment do
    count = Outbox::PublishingWorker.new.run
    puts "Processed #{count} outbox event(s)."
  end

  desc "Poll outbox and publish events every INTERVAL seconds (default: 5). Stop with Ctrl+C."
  task :publish, [:interval_seconds] => :environment do |_t, args|
    interval = (args[:interval_seconds] || 5).to_i
    interval = 1 if interval < 1
    puts "Outbox publishing started (interval=#{interval}s). Press Ctrl+C to stop."
    loop do
      count = Outbox::PublishingWorker.new.run
      puts "[#{Time.current.iso8601}] Processed #{count} event(s)." if count.positive?
      sleep interval
    end
  end
end
