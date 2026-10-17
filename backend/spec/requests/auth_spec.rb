require "rails_helper"

RSpec.describe "Авторизация и refresh-токены", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:credentials) { { email: "student@example.com", password: "secret123" } }

  def json
    JSON.parse(response.body)
  end

  def sign_up
    post "/signup", params: credentials, as: :json
    json
  end

  describe "POST /signup" do
    context "с корректными данными (happy path)" do
      it "создаёт пользователя и выдаёт access и refresh токены" do
        sign_up

        expect(response).to have_http_status(:created)
        expect(json["user"]["email"]).to eq("student@example.com")
        expect(json["accessToken"]).to be_present
        expect(json["refreshToken"]).to be_present
        expect(RefreshToken.count).to eq(1)
      end
    end

    context "с неподходящими данными" do
      it "не регистрирует повторный email" do
        sign_up
        post "/signup", params: credentials, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["errors"]).to be_present
      end

      it "не принимает короткий пароль" do
        post "/signup", params: { email: "a@example.com", password: "123" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /login" do
    before { sign_up }

    context "с верным паролем" do
      it "возвращает токены" do
        post "/login", params: credentials, as: :json

        expect(response).to have_http_status(:ok)
        expect(json["accessToken"]).to be_present
      end
    end

    context "с неверными данными" do
      it "отвечает 401 при неверном пароле" do
        post "/login", params: credentials.merge(password: "nope-nope"), as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "даёт то же сообщение для несуществующего email (не раскрывает, кто зарегистрирован)" do
        post "/login", params: credentials.merge(password: "nope-nope"), as: :json
        wrong_password_error = json["error"]

        post "/login", params: { email: "nobody@example.com", password: "secret123" }, as: :json

        expect(json["error"]).to eq(wrong_password_error)
      end
    end
  end

  describe "POST /auth/token" do
    context "пока refresh-токен действителен (happy path)" do
      it "выдаёт новый access-токен, которым можно открыть /me" do
        refresh = sign_up["refreshToken"]

        post "/auth/token", params: { token: refresh }, as: :json
        expect(response).to have_http_status(:ok)

        get "/me", headers: { "Authorization" => "Bearer #{json['accessToken']}" }
        expect(response).to have_http_status(:ok)
        expect(json["user"]["email"]).to eq("student@example.com")
      end
    end

    context "через 30 дней" do
      it "refresh-токен перестаёт работать" do
        refresh = sign_up["refreshToken"]

        travel_to(31.days.from_now) do
          post "/auth/token", params: { token: refresh }, as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it "в последний день ещё работает" do
        refresh = sign_up["refreshToken"]

        travel_to(29.days.from_now) do
          post "/auth/token", params: { token: refresh }, as: :json

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "с чужим или неверным токеном" do
      it "не принимает access-токен вместо refresh" do
        access = sign_up["accessToken"]

        post "/auth/token", params: { token: access }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "не принимает выдуманную строку" do
        post "/auth/token", params: { token: "garbage" }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /logout" do
    context "когда пользователь выходит" do
      it "отзывает refresh-токен: обменять его больше нельзя" do
        refresh = sign_up["refreshToken"]

        delete "/logout", params: { token: refresh }, as: :json
        expect(response).to have_http_status(:ok)

        post "/auth/token", params: { token: refresh }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "когда токен уже просрочен" do
      it "всё равно отзывается" do
        refresh = sign_up["refreshToken"]

        travel_to(31.days.from_now) do
          delete "/logout", params: { token: refresh }, as: :json
        end

        expect(RefreshToken.last).to be_revoked
      end
    end
  end

  describe "GET /me" do
    context "без токена или с неподходящим токеном" do
      it "отвечает 401 без заголовка" do
        get "/me"

        expect(response).to have_http_status(:unauthorized)
      end

      it "не принимает refresh-токен как access" do
        refresh = sign_up["refreshToken"]

        get "/me", headers: { "Authorization" => "Bearer #{refresh}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "не принимает просроченный access-токен (через 15 минут)" do
        access = sign_up["accessToken"]

        travel_to(16.minutes.from_now) do
          get "/me", headers: { "Authorization" => "Bearer #{access}" }

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
