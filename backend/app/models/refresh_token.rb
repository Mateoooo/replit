class RefreshToken < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active,  -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :stale,   -> { where("expires_at <= ? OR revoked_at IS NOT NULL", Time.current) }

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  # Возвращает [запись, сырой_токен]. Сырой токен в БД не хранится — только SHA256.
  def self.issue_for(user, user_agent: nil)
    user.refresh_tokens.stale.delete_all
    raw = SecureRandom.urlsafe_base64(48)
    record = create!(
      user: user,
      token_digest: digest(raw),
      expires_at: LIFETIME.from_now,
      user_agent: user_agent.to_s.truncate(255).presence
    )
    [record, raw]
  end

  def self.find_active_by_raw(raw)
    return nil if raw.blank?

    active.includes(:user).find_by(token_digest: digest(raw))
  end

  def self.revoke_by_raw(raw)
    return false if raw.blank?

    record = find_by(token_digest: digest(raw))
    record ? record.revoke! : false
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
    true
  end
end
