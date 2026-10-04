require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "session@example.com",
      password: "secret123"
    )
  end

  # === POST /login ===

  test "login with valid credentials returns tokens" do
    post "/login", params: {
      email: "session@example.com",
      password: "secret123"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_not_nil json["accessToken"]
    assert_not_nil json["refreshToken"]
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.email, json["user"]["email"]
  end

  test "login saves refresh_token to user" do
    post "/login", params: {
      email: "session@example.com",
      password: "secret123"
    }, as: :json

    @user.reload
    assert_not_nil @user.refresh_token
  end

  test "login with wrong password returns 401" do
    post "/login", params: {
      email: "session@example.com",
      password: "wrongpass"
    }, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Неверный email или пароль", json["error"]
  end

  test "login with unknown email returns 401" do
    post "/login", params: {
      email: "nobody@example.com",
      password: "secret123"
    }, as: :json

    assert_response :unauthorized
  end

  # === POST /auth/token ===

  test "refresh returns new access token with valid refresh" do
    post "/login", params: {
      email: "session@example.com",
      password: "secret123"
    }, as: :json
    refresh = JSON.parse(response.body)["refreshToken"]

    post "/auth/token", params: { token: refresh }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_not_nil json["accessToken"]
  end

  test "refresh returns 401 with invalid refresh token" do
    post "/auth/token", params: { token: "garbage" }, as: :json

    assert_response :unauthorized
  end

  test "refresh returns 401 with refresh token not in DB" do
    # Токен валидный по подписи, но не сохранён у юзера
    token = JsonWebToken.encode(
      { user_id: @user.id, type: "refresh" },
      30.days.from_now
    )

    post "/auth/token", params: { token: token }, as: :json

    assert_response :unauthorized
  end

  # === DELETE /logout ===

  test "logout clears refresh_token" do
    post "/login", params: {
      email: "session@example.com",
      password: "secret123"
    }, as: :json
    refresh = JSON.parse(response.body)["refreshToken"]

    delete "/logout", params: { token: refresh }, as: :json

    assert_response :success
    @user.reload
    assert_nil @user.refresh_token
  end

  test "logout with garbage token still returns 200" do
    delete "/logout", params: { token: "garbage" }, as: :json
    assert_response :success
  end
end