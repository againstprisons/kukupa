module Kukupa::Helpers::NavbarHelpers
  def navbar_items_logged_in
    items = []

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
end
