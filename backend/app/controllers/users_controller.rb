class UsersController < ApplicationController
  def create
    user = User.new(email: params[:email], password: params[:password])

    if user.save
      session[:user_id] = user.id
      render json: { id: user.id, email: user.email }
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def me
    user = User.find_by(id: session[:user_id])
    if user
      render json: { id: user.id, email: user.email }
    else
      render json: { error: "Не авторизован" }, status: :unauthorized
    end
  end
end