# frozen_string_literal: true

class OrdersController < ApplicationController
  def show
    order = Order.find_by(id: params[:id])
    return head :not_found unless order

    render json: order_as_json(order)
  end

  def create
    result = create_order_service.call

    if result.success?
      order = result.value.order
      status = result.value.created ? :created : :ok
      render json: order_as_json(order), status: status
    else
      render_error(result)
    end
  end

  private

  def create_order_service
    Orders::CreateOrder.new(
      params: order_params,
      idempotency_key: idempotency_key,
      customer_client: customer_client
    )
  end

  def order_params
    params.permit(:customer_id, :product_name, :quantity, :price, :status).to_h
  end

  def idempotency_key
    request.headers["Idempotency-Key"].presence
  end

  def customer_client
    nil
  end

  def order_as_json(order)
    {
      id: order.id,
      customer_id: order.customer_id,
      product_name: order.product_name,
      quantity: order.quantity,
      price: order.price.to_f,
      status: order.status,
      created_at: order.created_at.iso8601(3)
    }
  end

  def render_error(result)
    status = {
      customer_not_found: :unprocessable_content,
      unauthorized: :unauthorized,
      service_unavailable: :service_unavailable
    }.fetch(result.error_code, :unprocessable_content)
    render json: { error: result.error_code.to_s, message: result.message }, status: status
  end
end
