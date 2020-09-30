class Kukupa::Controllers::SystemDebugController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/flashes', method: :flashes

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debug")
  end

  def index
    @title = t(:'system/debug/title')

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/debug/index', layout: false, locals: {
        title: @title,
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
end
