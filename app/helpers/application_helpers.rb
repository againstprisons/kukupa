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

  def style_options_to_css(opts)
    raw_output = []
    root_vars = {}

    ###
    # Collate options
    ###    

    if opts[:full_width]
      root_vars['--body-container-width'] = '100vw'
    end

    if opts[:line_height]
      root_vars['--body-line-height'] = '200%';
    end

    if opts[:alternate_font]
      root_vars['--body-font-family'] = case opts[:alternate_font]
      when 'opendyslexic'
        '"opendyslexic", "OpenDyslexic", sans-serif'
      when 'comicsans'
        '"Comic Sans MS", sans-serif'
      else
        'sans-serif'
      end
    end

    ###
    # Put together the root var list and return the output CSS
    ###

    raw_output << ":root{#{root_vars.map{|k, v| "#{k}:#{v}"}.join(';')}}"
    raw_output.join("\n")
  end
end
