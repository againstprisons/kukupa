class Kukupa::Models::Token < Sequel::Model
  many_to_one :user

  def self.generate_long
    token = Kukupa::Crypto.generate_token_long
    self.new(token: token, valid: true, expiry: nil)
  end

  def self.generate_short
    token = Kukupa::Crypto.generate_token_short
    self.new(token: token, valid: true, expiry: nil)
  end

  def check_validity!
    return false unless self.valid

    if self.expiry && Time.now >= self.expiry
      self.invalidate! if self.valid
      return false
    end

    return true
  end

  def invalidate!
    self.valid = false
    self.save
  end
end
