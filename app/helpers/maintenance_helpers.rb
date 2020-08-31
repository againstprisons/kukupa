module Kukupa::Helpers::MaintenanceHelpers
  def is_maintenance?
    t = Kukupa::Models::Config.where(key: 'maintenance').first
    return false unless t
    return t.value == 'yes'
  end

  def maintenance_path_allowed?
    return true unless is_maintenance?
    return true if current_prefix?('/auth') && !current?('/auth/signup')
    return true if current_prefix?('/static')
    return true if logged_in? && has_role?('site:use_during_maintenance')

    false
  end

  def maintenance_render
    haml(:'errors/maintenance', :layout => :layout_minimal, :locals => {
      :title => t(:'errors/maintenance/title'),
      :no_flash => true,
    })
  end
end

