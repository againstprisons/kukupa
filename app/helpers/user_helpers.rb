module Kukupa::Helpers::UserHelpers
  def current_token
    return nil unless session.key?(:token)

    t = Kukupa::Models::Token.where(token: session[:token], use: 'session').first
    return nil unless t
    return nil unless t.check_validity!

    t
  end

  def logged_in?
    !current_token.nil?
  end

  def current_user
    return nil unless logged_in?
    current_token.user
  end

  def current_user_name_or_email
    return nil unless logged_in?
    u = current_user

    unless u.name.empty?
      return u.decrypt(:name)
    end

    u.email
  end

  # TODO: migrate all uses of this method to directly use User#has_role?
  # and remove this method
  def has_role?(role, opts = {})
    user = opts[:user] || current_user
    user&.has_role?(role, opts) || false
  end
end
