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

    @my_tasks = Kukupa::Models::CaseTask.where(assigned_to: @user.id, completion: nil).map do |t|
      c = Kukupa::Models::Case[t.case]
      curl = Addressable::URI.parse(url("/case/#{c.id}/view#case-view-tasks"))
      turl = Addressable::URI.parse(url("/case/#{c.id}/task/#{t.id}"))
      content = Sanitize.fragment(t.decrypt(:content).to_s, Sanitize::Config::RESTRICTED)

      {
        case: c,
        name: c.get_name,
        curl: curl.to_s,
        turl: turl.to_s,
        content: content,
      }
    end

    @my_cases = Kukupa::Models::Case.where(assigned_advocate: @user.id).map do |c|
      url = Addressable::URI.parse(url("/case/#{c.id}/view"))

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
      tasks: @my_tasks,
    })
  end
end
