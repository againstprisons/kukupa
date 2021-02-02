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
      }
    end

    advocates
  end

  def case_assignable_users
    uids = []

    # all users with `case:*` or `case:assignable` roles
    uids << Kukupa::Models::UserRole.where(role: "*").map(&:user_id).to_a
    uids << Kukupa::Models::UserRole.where(role: "case:*").map(&:user_id).to_a
    uids << Kukupa::Models::UserRole.where(role: "case:assignable").map(&:user_id).to_a

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
    uids << Kukupa::Models::UserRole.where(role: "*").map(&:user_id).to_a
    uids << Kukupa::Models::UserRole.where(role: "case:*").map(&:user_id).to_a
    uids << Kukupa::Models::UserRole.where(role: "case:view_all").map(&:user_id).to_a

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
    u = u.id if u.respond_to?(:id)
    u = Kukupa::Models::User[u]

    return true if has_role?('case:view_all', user: u)
    return true if c.get_assigned_advocates.include?(u.id)

    false
  end
end
