module Kukupa::Helpers::NavbarHelpers
  def navbar_items_logged_in
    items = []

    items << {
      :link => '/dashboard',
      :text => t(:'dashboard/title'),
      :selected => current?('/dashboard'),
    }

    items
  end

  def navbar_items
    return navbar_items_logged_in() if logged_in?
    items = []

    items
  end
end
