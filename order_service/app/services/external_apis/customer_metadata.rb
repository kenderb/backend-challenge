# frozen_string_literal: true

module ExternalApis
  CustomerMetadata = Struct.new(:customer_name, :address, :orders_count, keyword_init: true)
end
