module Kukupa::Helpers::SystemRolesHelpers
  def role_search_friendly(type, value)
    if type == :role
      if value == '*'
        return t(:'system/roles/search_results/description/all_roles')
      end

      return t(:'system/roles/search_results/description/role', value: value)
    end

    if type == :uid
      return t(:'system/roles/search_results/description/user_id', value: value)
    end

    if type == :email
      return t(:'system/roles/search_results/description/email', value: value)
    end

    t(:'system/roles/search_results/description/unknown', type: type, value: value)
  end
end
