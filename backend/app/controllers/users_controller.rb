class UsersController < ApplicationController
  include TokenIssuing

  def create
    user = User.new(email: params[:email], password: params[:password])

    if user.save
      render json: { user: user_json(user), **issue_tokens_for(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def me
    if current_user
      render json: { user: user_json(current_user) }
    else
      render json: { error: "Не авторизован" }, status: :unauthorized
    end
  end
end
