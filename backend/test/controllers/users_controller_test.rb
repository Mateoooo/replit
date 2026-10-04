require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  # === POST /signup ===

  test "signup creates user and returns tokens" do
    assert_difference "User.count", 1 do
      post "/signup", params: {
        email: "new@example.com",
        password: "secret123"
      }, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_not_nil json["accessToken"]
    assert_not_nil json["refreshToken"]
    assert_equal "new@example.com", json["user"]["email"]
  end

  test "signup with duplicate email returns 422" do
    User.create!(email: "dup@example.com", password: "secret123")

    assert_no_difference "User.count" do
      post "/signup", params: {
        email: "dup@example.com",
        password: "secret123"
      }, as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any? { |e| e.include?("taken") }
  end

  test "signup with short password returns 422" do
    post "/signup", params: {
      email: "short@example.com",
      password: "123"
    }, as: :json

    assert_response :unprocessable_entity
  end

  # === GET /me ===

  test "me returns user with valid token" do
    user = User.create!(email: "me@example.com", password: "secret123")
    token = JsonWebToken.encode({ user_id: user.id, type: "access" })

    get "/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal user.id, json["user"]["id"]
    assert_equal "me@example.com", json["user"]["email"]
  end

  test "me without token returns 401" do
    get "/me"
    assert_response :unauthorized
  end

  test "me with garbage token returns 401" do
    get "/me", headers: { "Authorization" => "Bearer garbage" }
    assert_response :unauthorized
  end

  test "me with refresh token instead of access returns 401" do
    user = User.create!(email: "me2@example.com", password: "secret123")
    # Токен с type: "refresh" — не должен приниматься
    token = JsonWebToken.encode({ user_id: user.id, type: "refresh" })

    get "/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end

  test "me with expired access token returns 401" do
    user = User.create!(email: "me3@example.com", password: "secret123")
    token = JsonWebToken.encode(
      { user_id: user.id, type: "access" },
      1.second.ago
    )

    get "/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end
end