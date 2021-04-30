class Kukupa::Controllers::ErrorController < Kukupa::Controllers::ApplicationController
  add_route :get, "/404", method: :not_found
  add_route :get, "/418", method: :teapot
  add_route :get, "/500", method: :server_error

  def not_found
    haml(:'errors/not_found', locals: {
      title: t(:'errors/not_found/title'),
    })
  end

  def teapot
    haml(:'errors/teapot', layout: :layout_minimal, locals: {
      title: t(:'errors/teapot/title'),
      no_flash: true,
    })
  end

  def server_error
    haml(:'errors/internal_server_error', layout: :layout_minimal, locals: {
      title: t(:'errors/internal_server_error/title'),
      no_flash: true,
    })
  end
end
