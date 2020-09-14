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
    @my_cases = Kukupa::Models::Case.where(assigned_advocate: @user.id).map do |c|
      url = Addressable::URI.parse(url("/case/#{c.id}"))

      {
        :case => c,
        :name => c.get_name,
        :url => url.to_s,
      }
    end

    return haml(:'dashboard/index', :locals => {
      :title => @title,
      :user => {
        :user => @user,
        :name => @user_name,
      },
      cases: @my_cases,
    })
  end
end
