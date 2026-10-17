require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "encode returns a JWT string" do
    token = JsonWebToken.encode({ user_id: 1, type: "access" })
    assert_kind_of String, token
    assert_equal 3, token.split(".").length, "JWT должен иметь 3 части"
  end

  test "decode returns the original payload" do
    token = JsonWebToken.encode({ user_id: 42, type: "access" })
    payload = JsonWebToken.decode(token)

    assert_not_nil payload
    assert_equal 42, payload[:user_id]
    assert_equal "access", payload[:type]
  end

  test "decode supports string keys" do
    token = JsonWebToken.encode({ user_id: 42, type: "access" })
    payload = JsonWebToken.decode(token)

    assert_equal 42, payload["user_id"]
    assert_equal "access", payload["type"]
  end

  test "decode returns nil for expired token" do
    token = JsonWebToken.encode(
      { user_id: 1, type: "access" },
      1.second.ago
    )
    assert_nil JsonWebToken.decode(token)
  end

  test "decode returns nil for garbage string" do
    assert_nil JsonWebToken.decode("not-a-real-token")
  end

  test "decode returns nil for empty string" do
    assert_nil JsonWebToken.decode("")
  end

  test "decode returns nil for tampered token" do
    token = JsonWebToken.encode({ user_id: 1, type: "access" })
    # Меняем последние 3 символа подписи
    tampered = token[0..-4] + "XXX"
    assert_nil JsonWebToken.decode(tampered)
  end

  test "refresh token has longer expiration than access" do
    access = JsonWebToken.encode({ user_id: 1, type: "access" }, 15.minutes.from_now)
    refresh = JsonWebToken.encode({ user_id: 1, type: "refresh" }, 30.days.from_now)

    access_payload = JsonWebToken.decode(access)
    refresh_payload = JsonWebToken.decode(refresh)

    assert refresh_payload[:exp] > access_payload[:exp]
  end

  test "decode preserves exp" do
    exp = 1.hour.from_now
    token = JsonWebToken.encode({ user_id: 1 }, exp)
    payload = JsonWebToken.decode(token)

    assert_in_delta exp.to_i, payload[:exp], 1
  end
end
