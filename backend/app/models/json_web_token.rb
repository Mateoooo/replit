# для access-токенов
class JsonWebToken
  SECRET = Rails.application.secret_key_base
  ACCESS_TTL = 15.minutes

  def self.encode(payload, exp = ACCESS_TTL.from_now)
    payload = payload.dup
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET, "HS256")
  end

  def self.access_for(user)
    encode({ user_id: user.id, type: "access" })
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, algorithm: "HS256").first
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError
    nil
  end
end
