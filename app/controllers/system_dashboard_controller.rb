class Kukupa::Controllers::SystemDashboardController < Kukupa::Controllers::SystemController
  add_route :get, '/'

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")
  end

  def index
    @title = t(:'system/index/title')

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/index', layout: false, locals: {
        title: @title,
      })
    end
  end
end
