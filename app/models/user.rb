require 'addressable'

class Kukupa::Models::User < Sequel::Model
  one_to_many :user_roles
  one_to_many :tokens

  def case_count
    Kukupa::Models::CaseAssignedAdvocate
      .where(user: self.id)
      .count
  end

  def mfa_data
    recovery_tokens = Kukupa::Models::Token.where(
      user_id: self.id,
      use: 'mfa_recovery',
      valid: true,
    )

    {
      enabled: self.totp_enabled,
      has_key: false, # TODO: add U2F / WebAuthn support
      has_recovery: recovery_tokens.count.positive?,
      has_roles: self.user_roles.count.positive?,
    }
  end

  def mfa_totp_instance
    ROTP::TOTP.new(
      self.decrypt(:totp_secret),
      issuer: Kukupa.app_config['site-name']
    )
  end

  def password=(pw)
    self.password_hash = Kukupa::Crypto.password_hash(pw)
  end

  def password_correct?(pw)
    return false if self.password_hash.nil?
    return false if self.password_hash&.empty?

    Kukupa::Crypto.password_verify(self.password_hash, pw)
  end

  def login!
    token = Kukupa::Models::Token.generate_long
    token.user = self
    token.use = "session"
    token.save

    token
  end

  def invalidate_tokens!
    invalidate_tokens_except!(nil)
  end

  def invalidate_tokens_except!(token)
    to_invalidate = Kukupa::Models::Token.where(
      user_id: self.id,
      use: 'session',
      valid: true,
    ).all

    unless token.nil?
      token = token.token if token.respond_to?(:token)
      to_invalidate.reject!{|x| x.token == token}
    end

    to_invalidate.map(&:invalidate!)
  end

  def delete!
    self.tokens.map(&:delete)
    self.user_roles.map(&:delete)

    self.delete
  end
end
