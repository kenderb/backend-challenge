# frozen_string_literal: true

module InternalApiKeyAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :validate_internal_api_key
  end

  private

  def validate_internal_api_key
    key = request.headers["X-Internal-Api-Key"]
    expected = ENV["INTERNAL_API_KEY"].presence || Rails.application.credentials.internal_api_key

    return head :unauthorized if expected.blank?
    return head :unauthorized if key.blank? || key != expected

    true
  end
end
