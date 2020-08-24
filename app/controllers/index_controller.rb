class Kukupa::Controllers::IndexController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"

  def index
    if logged_in?
      return redirect to("/dashboard")
    end

    @title = t(:'index/title')
    haml :'index/index', :locals => {
      :title => @title,
    }
  end
end
