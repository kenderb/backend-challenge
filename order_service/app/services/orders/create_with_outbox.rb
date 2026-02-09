# frozen_string_literal: true

module Orders
  # @deprecated Use CreateOrder. Kept for backward compatibility.
  class CreateWithOutbox
    def self.call(params, idempotency_key: nil, customer_client: nil)
      CreateOrder.call(params, idempotency_key: idempotency_key, customer_client: customer_client)
    end
  end
end
