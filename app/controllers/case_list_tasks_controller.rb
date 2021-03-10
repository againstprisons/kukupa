require 'chronic'

class Kukupa::Controllers::CaseListTasksController < Kukupa::Controllers::ApplicationController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseListTasksHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("case:list:tasks")
  end

  def index
    @group_by_assignee = request.params['gba'].to_i.positive?
    @tasks = case_task_list_tasks(group_by_assignee: @group_by_assignee)

    @title = t(:'case/list_tasks/title')
    return haml(:'case/list_tasks', :locals => {
      cuser: @user,
      title: @title,
      group_by_assignee: @group_by_assignee,
      tasks: @tasks,
    })
  end
end
