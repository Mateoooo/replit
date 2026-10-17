require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(attrs = {})
    User.new({
      email: "test@example.com",
      password: "secret123"
    }.merge(attrs))
  end

  # === Валидность ===

  test "valid with email and password" do
    user = build_user
    assert user.valid?
  end

  test "invalid without email" do
    user = build_user(email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid without password" do
    user = build_user(password: nil)
    assert_not user.valid?
  end

  test "invalid with short password" do
    user = build_user(password: "123")
    assert_not user.valid?
  end

  test "invalid with duplicate email" do
    User.create!(email: "dup@example.com", password: "secret123")
    user = build_user(email: "dup@example.com")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "invalid with malformed email" do
    user = build_user(email: "not-an-email")
    assert_not user.valid?
  end

  # === Сохранение ===

  test "saves user with hashed password" do
    user = build_user
    user.save!
    assert_not_nil user.password_digest
    assert_not_equal "secret123", user.password_digest
    assert user.password_digest.start_with?("$2a$")
  end

  test "does not save raw password" do
    user = build_user(password: "secret123")
    user.save!
    assert_nil user[:password]
    assert_not_nil user.password_digest
  end

  # === authenticate ===

  test "authenticate returns user with correct password" do
    user = User.create!(email: "auth@example.com", password: "secret123")
    assert_equal user, user.authenticate("secret123")
  end

  test "authenticate returns false with wrong password" do
    user = User.create!(email: "auth@example.com", password: "secret123")
    assert_not user.authenticate("wrongpass")
  end

  test "authenticate returns false with nil password" do
    user = User.create!(email: "auth@example.com", password: "secret123")
    assert_not user.authenticate(nil)
  end

  # === refresh_token ===

  test "refresh_token is nil by default" do
    user = User.create!(email: "rt@example.com", password: "secret123")
    assert_nil user.refresh_token
  end

  test "refresh_token can be set and persisted" do
    user = User.create!(email: "rt@example.com", password: "secret123")
    user.update!(refresh_token: "some.jwt.token")
    user.reload
    assert_equal "some.jwt.token", user.refresh_token
  end

  test "refresh_token can be cleared" do
    user = User.create!(
      email: "rt@example.com",
      password: "secret123",
      refresh_token: "some.jwt.token"
    )
    user.update!(refresh_token: nil)
    user.reload
    assert_nil user.refresh_token
  end
end
