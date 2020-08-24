require 'addressable'

class Kukupa::Models::User < Sequel::Model
  one_to_many :user_roles
  one_to_many :tokens

  def password=(pw)
    self.password_hash = Kukupa::Crypto.password_hash(pw)
  end

  def password_correct?(pw)
    return false if self.password_hash.nil?
    return false if self.password_hash&.empty?

    Kukupa::Crypto.password_verify(self.password_hash, pw)
  end

  def login!
    token = Kukupa::Models::Token.generate
    token.user = self
    token.use = "session"
    token.save

    token
  end

  def invalidate_tokens!
    invalidate_tokens_except!(nil)
  end

  def invalidate_tokens_except!(token)
    to_invalidate = self.tokens
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
