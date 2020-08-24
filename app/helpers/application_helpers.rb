module Kukupa::Helpers::ApplicationHelpers
  require_relative './language_helpers'
  include Kukupa::Helpers::LanguageHelpers

  require_relative './maintenance_helpers'
  include Kukupa::Helpers::MaintenanceHelpers

  require_relative './csrf_helpers'
  include Kukupa::Helpers::CsrfHelpers

  require_relative './time_helpers'
  include Kukupa::Helpers::TimeHelpers

  require_relative './theme_helpers'
  include Kukupa::Helpers::ThemeHelpers

  require_relative './flash_helpers'
  include Kukupa::Helpers::FlashHelpers

  require_relative './user_helpers'
  include Kukupa::Helpers::UserHelpers

  require_relative './navbar_helpers'
  include Kukupa::Helpers::NavbarHelpers

  def site_name
    Kukupa.app_config["site-name"]
  end

  def org_name
    Kukupa.app_config["org-name"]
  end

  def current_prefix?(path = '/')
    request.path.start_with?(path) ? 'current' : nil
  end

  def current?(path = '/')
    request.path == path ? 'current' : nil
  end
end
