class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      render json: { id: user.id, email: user.email }
    else
      render json: { error: "Неверный email или пароль" }, status: :unauthorized
    end
  end

  def destroy
    session.delete(:user_id)
    render json: { ok: true }
  end
end