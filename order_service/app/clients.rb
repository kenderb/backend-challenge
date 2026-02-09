# frozen_string_literal: true

module Clients
  # Abstraction for the Customer Service HTTP API. Wraps Faraday/HTTP logic so the
  # controller and services depend on this client, not on the underlying implementation.
  # Injected into Orders::CreateOrder; defaults to ExternalApis::CustomerClient for HTTP.
  class CustomerServiceClient
    def initialize(adapter: nil)
      @adapter = adapter || ExternalApis::CustomerClient.new
    end

    # @param customer_id [Integer, String]
    # @return [ExternalApis::CustomerMetadata] on success
    # @raise [Errors::CustomerNotFound] when customer does not exist (404)
    # @raise [Errors::UnauthorizedError] when API key is invalid (401)
    # @raise [Errors::CustomerServiceUnavailable] on 5xx, connection, or timeout
    delegate :fetch_customer, to: :adapter

    private

    attr_reader :adapter
  end
end
