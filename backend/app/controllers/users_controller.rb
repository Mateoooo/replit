class UsersController < ApplicationController
  def create
    user = User.new(email: params[:email], password: params[:password])

    if user.save
      tokens = generate_tokens(user)
      user.update!(refresh_token: tokens[:refreshToken])
      render json: { user: user_json(user), **tokens }, status: :created
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

  private

  def generate_tokens(user)
    {
      accessToken: JsonWebToken.encode(
        { user_id: user.id, type: "access" },
        15.minutes.from_now
      ),
      refreshToken: JsonWebToken.encode(
        { user_id: user.id, type: "refresh" },
        30.days.from_now
      )
    }
  end

  def user_json(user)
    { id: user.id, email: user.email }
  end
end