module Kukupa::Helpers::NavbarHelpers
  def navbar_items_logged_in
    items = []

    items << {
      link: url('/case'),
      text: t(:'case/index/title'),
      selected: current_prefix?('/case'),
    }

    if has_role?('case:assignable')
      items << {
        :link => url('/prison-assignees'),
        :text => t(:'prison_signup/title'),
        :selected => current_prefix?('/prison-assignees'),
      }
    end

    if has_role?('system:access')
      items << {
        :link => url('/system'),
        :text => t(:'system/index/title'),
        :selected => current_prefix?('/system'),
      }
    end

    items
  end

  def navbar_items
    return navbar_items_logged_in() if logged_in?
    items = []

    items
  end
  
  def navbar_sub_items_usersettings
    items = []

    items << {
      link: url('/user'),
      text: t(:'usersettings/title'),
      selected: current?('/user'),
    }

    items << {
      link: url('/user/mfa'),
      text: t(:'usersettings/mfa/title'),
      selected: current_prefix?('/user/mfa'),
    }

    if Kukupa.app_config['privacy-agreement-enable']
      items << {
        link: url('/user/privacy-agreement'),
        text: t(:'usersettings/privacy_agreement/title'),
        selected: current_prefix?('/user/privacy-agreement'),
      }
    end
    
    items
  end

  def navbar_sub_items_system
    items = []

    items << {
      link: url('/system'),
      text: t(:'system/index/title'),
      selected: current?('/system'),
    }

    if has_role?('system:config:access')
      items << {
        link: url('/system/config'),
        text: t(:'system/config/title'),
        selected: current_prefix?('/system/config'),
      }
    end

    if has_role?('system:roles:access')
      items << {
        link: url('/system/roles'),
        text: t(:'system/roles/title'),
        selected: current_prefix?('/system/roles'),
      }
    end

    if has_role?('system:outside_request')
      items << {
        link: url('/system/outside-request'),
        text: t(:'system/outside_request/title'),
        selected: current_prefix?('/system/outside-request'),
      }
    end

    if has_role?('system:prison:access')
      items << {
        link: url('/system/prison'),
        text: t(:'system/prison/title'),
        selected: current_prefix?('/system/prison'),
      }
    end

    if has_role?('system:mail_templates')
      items << {
        link: url('/system/mailtemplates'),
        text: t(:'system/mail_templates/title'),
        selected: current_prefix?('/system/mailtemplates'),
      }
    end

    if has_role?('system:quicklinks')
      items << {
        link: url('/system/quick-links'),
        text: t(:'system/quicklinks/title'),
        selected: current_prefix?('/system/quick-links'),
      }
    end

    if has_role?('system:worker')
      items << {
        link: url('/system/worker'),
        text: t(:'system/worker/title'),
        selected: current_prefix?('/system/worker'),
      }
    end

    if has_role?('system:apikey:access')
      items << {
        link: url('/system/apikey'),
        text: t(:'system/apikey/title'),
        selected: current_prefix?('/system/apikey'),
      }
    end

    if has_role?('system:debug')
      items << {
        link: url('/system/debug'),
        text: t(:'system/debug/title'),
        selected: current_prefix?('/system/debug'),
      }
    end

    items
  end

  def navbar_sub_items
    if logged_in?
      return navbar_sub_items_usersettings() if current_prefix?('/user')
      return navbar_sub_items_system() if current_prefix?('/system')
    end

    []
  end
end
