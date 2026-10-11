class ApplicationController < ActionController::API
  include Authenticable

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Не найдено" }, status: :not_found
  end
end
