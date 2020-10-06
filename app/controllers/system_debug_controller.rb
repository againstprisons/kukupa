class Kukupa::Controllers::SystemDebugController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/flashes', method: :flashes
  add_route :get, '/routes', method: :routes

  include Kukupa::Helpers::SystemDebugHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debug")
  end

  def index
    @title = t(:'system/debug/title')
    @non_reconnect_prisons = Kukupa::Models::Prison.where(reconnect_id: nil).all.map(&:id)

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/debug/index', layout: false, locals: {
        title: @title,
        non_reconnect_prisons: @non_reconnect_prisons,
      })
    end
  end

  def flashes
    @title = t(:'system/debug/flashes/title')

    %i[success warning error].each do |type|
      flash type, t(:'system/debug/flashes/flash', type: type)
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/debug/flashes', layout: false, locals: {
        title: @title,
      })
    end
  end

  def routes
    @title = t(:'system/debug/routes/title')
    @controllers = debug_controller_list()

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/debug/routes', layout: false, locals: {
        title: @title,
        controllers: @controllers,
      })
    end
  end
end
