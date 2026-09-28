class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      tokens = generate_tokens(user)
      user.update!(refresh_token: tokens[:refreshToken])
      render json: { user: user_json(user), **tokens }
    else
      render json: { error: "Неверный email или пароль" }, status: :unauthorized
    end
  end

  def refresh
    payload = JsonWebToken.decode(params[:token])

    if payload && payload[:type] == "refresh"
      user = User.find_by(id: payload[:user_id], refresh_token: params[:token])

      if user
        new_access = JsonWebToken.encode(
          { user_id: user.id, type: "access" },
          15.minutes.from_now
        )
        return render json: { accessToken: new_access }
      end
    end

    render json: { error: "Невалидный refresh токен" }, status: :unauthorized
  end

  def destroy
    payload = JsonWebToken.decode(params[:token])

    if payload
      user = User.find_by(id: payload[:user_id])
      user&.update(refresh_token: nil)
    end

    render json: { ok: true }
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