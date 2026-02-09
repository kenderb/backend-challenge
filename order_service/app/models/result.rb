# frozen_string_literal: true

# Result object pattern for service API responses: Success(value) or Failure(error_code, message).
# Use for consistent handling of success/failure across services.
class Result
  Success = Struct.new(:value, keyword_init: true) do
    def success? = true
    def failure? = false
    def error_code = nil
    def message = nil
  end

  Failure = Struct.new(:error_code, :message, keyword_init: true) do
    def success? = false
    def failure? = true
    def value = nil
  end
end
