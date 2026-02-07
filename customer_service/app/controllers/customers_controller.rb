# frozen_string_literal: true

class CustomersController < ApplicationController
  include InternalApiKeyAuthenticatable

  def show
    @customer = Customer.find(params[:id])
    render json: @customer, status: :ok
  end
end
