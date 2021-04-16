module Kukupa::Helpers::CaseHelpers
  def case_populate_advocate(advocates, uid)
    unless advocates.key?(uid.to_s)
      adv = Kukupa::Models::User[uid.to_i]
      advocates[uid.to_s] ||= {
        obj: adv,
        id: adv&.id || 0,
        name: adv&.decrypt(:name) || t(:'unknown'),
        me: logged_in?() ? current_user.id == adv&.id : false,
        is_at_case_limit: adv&.is_at_case_limit?,
        tags: adv&.roles&.map{|r| /tag\:(\w+)/.match(r)&.[](1)}&.compact&.uniq || [],
      }
    end

    advocates
  end

  def case_assignable_users
    uids = []

    roles = ['*', 'case:*', 'case:assignable' ]

    roles.each do |role|
      # user-specific roles
      uids << Kukupa::Models::UserRole
        .where(role: role)
        .map(&:user_id)
        .to_a

      # user role groups
      uids << Kukupa::Models::RoleGroupRole
        .where(role: role)
        .map(&:role_group)
        .map(&:role_group_users)
        .flatten
        .map(&:user_id)
        .to_a
    end

    # get user objects
    advocates = {}
    uids.flatten.compact.each do |uid|
      advocates = case_populate_advocate(advocates, uid)
    end

    advocates.values.sort { |a, b| a[:id] <=> b[:id] }
  end

  def case_users_with_access(c)
    c = c.id if c.respond_to?(:id)
    c = Kukupa::Models::Case[c]

    # start with all assigned advocates for the case
    uids = c.get_assigned_advocates

    # all users with `case:*` or `case:view_all` roles
    ['*', 'case:*', 'case:view_all'].each do |role|
      uids << Kukupa::Models::UserRole.where(role: role).map(&:user_id).to_a
      Kukupa::Models::RoleGroupRole.where(role: role).each do |rgr|
        uids << rgr.role_group.role_group_users.map(&:user_id).to_a
      end
    end

    # get user objects
    advocates = {}
    uids.flatten.compact.each do |uid|
      advocates = case_populate_advocate(advocates, uid)
    end

    advocates.values.sort { |a, b| a[:id] <=> b[:id] }
  end

  def case_user_can_access?(c, u)
    c = c.id if c.respond_to?(:id)
    c = Kukupa::Models::Case[c]

    unless c.type == 'case'
      return true if !c.is_private
    end

    u = u.id if u.respond_to?(:id)
    u = Kukupa::Models::User[u]

    return true if has_role?('case:view_all', user: u)
    return true if c.get_assigned_advocates.include?(u.id)

    false
  end

  def case_users_group_by_tag(advocates)
    tagged = {}

    advocates.each do |adv|
      adv[:tags].each do |tag|
        tagged[tag] ||= []
        tagged[tag] << adv
      end

      if adv[:tags].empty?
        tagged['no_tags'] ||= []
        tagged['no_tags'] << adv
      end
    end

    tagged
  end
end
