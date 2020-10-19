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
      case_obj = Kukupa::Models::Case[t.case]
      view_url = Addressable::URI.parse(url("/case/#{case_obj.id}/view"))
      edit_url = Addressable::URI.parse(url("/case/#{case_obj.id}/task/#{t.id}"))
      content = Sanitize.fragment(t.decrypt(:content).to_s, Sanitize::Config::RESTRICTED)

      {
        case: case_obj,
        case_name: case_obj.get_name,
        task: t,
        task_content: content,
        view_url: view_url,
        edit_url: edit_url,
      }
    end

    @my_cases = Kukupa::Models::Case.assigned_to(@user).map do |c|
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
