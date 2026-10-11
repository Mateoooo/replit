module Authenticable
  extend ActiveSupport::Concern

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = load_user_from_token
  end

  def authenticate_user!
    render json: { error: "Не авторизован" }, status: :unauthorized unless current_user
  end

  private

  def load_user_from_token
    token = extract_token_from_header
    return nil unless token

    payload = JsonWebToken.decode(token)
    return nil unless payload && payload[:type] == "access"

    User.find_by(id: payload[:user_id])
  end

  def extract_token_from_header
    header = request.headers["Authorization"].to_s
    header.start_with?("Bearer ") ? header.delete_prefix("Bearer ").strip.presence : nil
  end
end
