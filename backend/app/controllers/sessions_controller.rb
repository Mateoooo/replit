class SessionsController < ApplicationController
  include TokenIssuing

  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    if user&.authenticate(params[:password].to_s)
      render json: { user: user_json(user), **issue_tokens_for(user) }
    else
      render json: { error: "Неверный email или пароль" }, status: :unauthorized
    end
  end

  def refresh
    record = RefreshToken.find_active_by_raw(params[:token])

    if record
      render json: { accessToken: JsonWebToken.access_for(record.user) }
    else
      render json: { error: "Невалидный refresh токен" }, status: :unauthorized
    end
  end

  def destroy
    RefreshToken.revoke_by_raw(params[:token])
    render json: { ok: true }
  end
end
