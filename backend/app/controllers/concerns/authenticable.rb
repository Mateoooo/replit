module Authenticable
  extend ActiveSupport::Concern
  
  included do
    before_action :authenticate_user!
  end

  def current_user
    @current_user ||= begin
      token = extract_token_from_header
      return nil unless token

      payload = JsonWebToken.decode(token)
      return nil unless payload && payload[:type] == "access"

      User.find_by(id: payload[:user_id])
    end
  end

  def authenticate_user!
    render json: { error: "Не авторизован" }, status: :unauthorized unless current_user
  end

  private

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.start_with?("Bearer ") ? header.split(" ").last : nil
  end
end