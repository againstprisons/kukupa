class Kukupa::Controllers::DashUserStylesController < Kukupa::Controllers::ApplicationController
  add_route :get, '/user.css', method: :user_css

  def user_css
    @style_options = Kukupa::Models::User::DEFAULT_STYLE_OPTIONS
    if @current_user
      @style_options = @current_user.style_options
    end

    content_type 'text/css'
    style_options_to_css(@style_options)
  end
end
