# frozen_string_literal: true

# Ensure Clients::CustomerServiceClient is loaded (avoids Zeitwerk lookup issues with top-level Clients).
require Rails.root.join("app/clients.rb").to_s
