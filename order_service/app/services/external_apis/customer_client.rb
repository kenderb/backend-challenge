# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "stoplight"

module ExternalApis
  class CustomerClient
    CUSTOMER_SERVICE_URL = "CUSTOMER_SERVICE_URL"
    INTERNAL_API_KEY = "INTERNAL_API_KEY"

    def initialize(base_url: nil, api_key: nil)
      @base_url = base_url.presence || ENV.fetch(CUSTOMER_SERVICE_URL, nil)
      @api_key = api_key.presence || ENV[INTERNAL_API_KEY].presence ||
                 (Rails.application.credentials.internal_api_key if Rails.application.respond_to?(:credentials))
    end

    # @param customer_id [Integer, String]
    # @return [CustomerMetadata] on success
    # @raise [Errors::CustomerNotFound] when customer does not exist (404)
    # @raise [Errors::ServiceUnavailable] on 5xx, connection, or timeout
    def fetch_customer(customer_id)
      customer_service_light.run { perform_fetch(customer_id) }
    rescue Stoplight::Error::RedLight => e
      raise Errors::ServiceUnavailable, e.message
    end

    private

    attr_reader :base_url, :api_key

    def customer_service_light
      @customer_service_light ||= Stoplight("customer_service")
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
      raise Errors::ServiceUnavailable, e.message
    end

    def map_response_to_result(response)
      case response.status
      when 200 then build_customer_metadata(response.body)
      when 404 then raise Errors::CustomerNotFound
      else raise Errors::ServiceUnavailable
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
        f.options.open_timeout = 2
        f.options.timeout = 5
        f.headers["X-Internal-Api-Key"] = api_key.to_s
        f.adapter Faraday.default_adapter
      end
    end

    def retry_options
      {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2
      }
    end
  end
end
