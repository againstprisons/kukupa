require 'chronic'

class Kukupa::Controllers::CaseListTasksController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseListTasksHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("case:list:tasks")
    @user = current_user
  end

  def index
    @tasks = case_task_list_tasks()

    @title = t(:'case/list_tasks/title')
    return haml(:'case/list_tasks', :locals => {
      cuser: @user,
      title: @title,
      tasks: @tasks,
    })
  end
end
