# frozen_string_literal: true

# JWT token generation and verification
class JwtService
  SECRET_KEY = Rails.application.credentials.secret_key_base.to_s
  ALGORITHM = "HS256"

  def self.generate(user)
    payload = {
      uuid: user.uuid,
      phone: user.phone,
      exp: 30.days.from_now.to_i,
      iat: Time.current.to_i,
    }
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.verify(token)
    JWT.decode(token, SECRET_KEY, true, algorithm: ALGORITHM).first
  rescue JWT::ExpiredSignature
    nil
  rescue JWT::DecodeError
    nil
  end
end
