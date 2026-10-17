module TokenIssuing
  extend ActiveSupport::Concern

  private

  def issue_tokens_for(user)
    _record, raw_refresh = RefreshToken.issue_for(user, user_agent: request.user_agent)
    { accessToken: JsonWebToken.access_for(user), refreshToken: raw_refresh }
  end

  def user_json(user)
    { id: user.id, email: user.email }
  end
end
