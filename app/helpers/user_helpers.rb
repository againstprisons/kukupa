module Kukupa::Helpers::UserHelpers
  def current_token
    return nil unless session.key?(:token)

    t = Kukupa::Models::Token.where(token: session[:token], :use => 'session').first
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

  def role_matches?(query, maybe_matches, opts = {})
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

  def has_role?(role, opts = {})
    user = opts[:user] || current_user
    return false unless user

    user_roles = [
      user.user_roles.map(&:role),
      user.role_group_users.map do |ug|
        ug.role_group.role_group_roles.map(&:role)
      end,
    ].flatten.compact

    if role_matches?(role, user_roles, :reject => true)
      return false
    end

    return role_matches?(role, user_roles)
  end
end
