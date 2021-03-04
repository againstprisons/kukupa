require 'addressable'

class Kukupa::Models::User < Sequel::Model
  one_to_many :user_roles
  one_to_many :role_group_users
  one_to_many :tokens

  def self.role_matches?(query, maybe_matches, opts = {})
    if opts[:reject]
      maybe_matches = maybe_matches.map do |m|
        next nil unless m.start_with?("!")
        m[1..-1]
      end.compact
    end

    query_parts = query.split(':')
    maybe_parts = maybe_matches.map{|x| x.split(':')}

    maybe_parts.each do |rp|
      skip = false
      oksofar = true

      rp.each_index do |rpi|
        next if skip

        if oksofar && rp[rpi] == '*'
          return true
        elsif rp[rpi] != query_parts[rpi]
          oksofar = false
          skip = true
        end
      end

      return true if oksofar
    end

    false
  end

  def roles
    [
      self.user_roles.map(&:role),
      self.role_group_users.map do |ug|
        ug.role_group.role_group_roles.map(&:role)
      end,
    ].flatten.compact
  end

  def has_role?(role, opts = {})
    user_roles = self.roles
    if self.class.role_matches?(role, user_roles, :reject => true)
      return false
    end

    return self.class.role_matches?(role, user_roles)
  end

  def case_count
    Kukupa::Models::CaseAssignedAdvocate
      .where(user: self.id)
      .count
  end
  
  def is_at_case_limit?
    return false if self.case_load_limit.zero?
    self.case_count >= self.case_load_limit
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
