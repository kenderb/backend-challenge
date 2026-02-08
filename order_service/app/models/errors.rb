# frozen_string_literal: true

module Errors
  class CustomerNotFound < StandardError
    def initialize(message = "Customer not found")
      super
    end
  end

  class ServiceUnavailable < StandardError
    def initialize(message = "Service unavailable")
      super
    end
  end

  # Raised when customer_service is down, 5xx, or timeout (for clearer domain semantics).
  class CustomerServiceUnavailable < ServiceUnavailable
    def initialize(message = "Customer service unavailable")
      super
    end
  end
end
