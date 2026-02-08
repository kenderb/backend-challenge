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
end
