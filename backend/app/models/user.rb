class User < ApplicationRecord
  has_secure_password

  has_many :refresh_tokens, dependent: :delete_all
  has_many :projects, dependent: :destroy
  has_many :runs, through: :projects

  before_validation { self.email = email.to_s.strip.downcase }

  validates :email, presence: true,
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: 6 }, allow_nil: true
end
