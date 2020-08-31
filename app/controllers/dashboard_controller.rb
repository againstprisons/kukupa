class Kukupa::Controllers::DashboardController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"

  def index
    unless logged_in?
      session[:after_login] = "/dashboard"
      return redirect to "/auth"
    end

    @title = t(:'dashboard/title')
    @user = current_user
    @user_name = @user.decrypt(:name)
    @user_name = nil if @user_name.nil? || @user_name&.empty?

    return haml(:'dashboard/index', :locals => {
      :title => @title,
      :user => {
        :user => @user,
        :name => @user_name,
      }
    })
  end
end