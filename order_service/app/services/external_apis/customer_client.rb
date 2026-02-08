# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "stoplight"

module ExternalApis
  # HTTP client for customer_service. Uses Faraday with retry and Stoplight circuit breaker
  # to fail fast when customer_service is unhealthy.
  class CustomerClient
    CUSTOMER_SERVICE_URL = "CUSTOMER_SERVICE_URL"
    INTERNAL_API_KEY = "INTERNAL_API_KEY"
    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

    def initialize(base_url: nil, api_key: nil)
      @base_url = base_url.presence || ENV.fetch(CUSTOMER_SERVICE_URL, nil)
      @api_key = api_key.presence || resolve_api_key
    end

    # @param customer_id [Integer, String]
    # @return [CustomerMetadata] on success
    # @raise [Errors::CustomerNotFound] when customer does not exist (404)
    # @raise [Errors::CustomerServiceUnavailable] on 5xx, connection, timeout, or circuit open
    def fetch_customer(customer_id)
      customer_service_light.run { perform_fetch(customer_id) }
    rescue Stoplight::Error::RedLight => e
      raise Errors::CustomerServiceUnavailable, e.message
    end

    private

    attr_reader :base_url, :api_key

    # Circuit breaker: fail fast when customer_service is unhealthy (e.g. repeated 5xx/timeouts).
    # 404 does not trip the circuit (error_handler re-raises CustomerNotFound).
    def customer_service_light
      @customer_service_light ||= Stoplight("customer_service")
                                  .with_threshold(3)
                                  .with_error_handler do |error, handle|
                                    raise error if error.is_a?(Errors::CustomerNotFound)

                                    handle.call(error)
                                  end
    end

    def perform_fetch(customer_id)
      raise ArgumentError, "CUSTOMER_SERVICE_URL is not set" if base_url.blank?

      response = connection.get("/customers/#{customer_id}")
      map_response_to_result(response)
    rescue Faraday::Error => e
      raise Errors::CustomerServiceUnavailable, e.message
    end

    def map_response_to_result(response)
      case response.status
      when 200 then build_customer_metadata(response.body)
      when 404 then raise Errors::CustomerNotFound
      else raise Errors::CustomerServiceUnavailable
      end
    end

    def build_customer_metadata(body)
      data = body.is_a?(String) ? JSON.parse(body) : body
      CustomerMetadata.new(
        customer_name: data["name"],
        address: data["address"],
        orders_count: data["orders_count"].to_i
      )
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.request :retry, retry_options
        f.request :json
        f.response :json, content_type: /\bjson/
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = READ_TIMEOUT
        f.headers["X-Internal-Api-Key"] = api_key.to_s
        f.adapter Faraday.default_adapter
      end
    end

    # Exponential backoff for idempotent GET; 3 attempts total (max: 2 retries).
    def retry_options
      {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2
      }
    end

    # Production: prefer credentials. Test/development: ENV then credentials.
    def resolve_api_key
      if Rails.env.production? && Rails.application.respond_to?(:credentials)
        Rails.application.credentials.internal_api_key
      else
        ENV[INTERNAL_API_KEY].presence ||
          (Rails.application.credentials.internal_api_key if Rails.application.respond_to?(:credentials))
      end
    end
  end
end
