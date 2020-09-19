class Kukupa::Controllers::CaseTaskEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/complete', method: :complete

  include Kukupa::Helpers::CaseHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid, tid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @task = Kukupa::Models::CaseTask[tid.to_i]
    return halt 404 unless @task
    return halt 404 unless @task.case == @case.id

    @accessors = case_users_with_access(@case)
    @case_name = @case.get_name
    @title = t(:'case/task/edit/title', task_id: @task.id, name: @case_name)

    if request.get?
      return haml(:'case/task/edit', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        case_accessors: @accessors,
        task_obj: @task,
        task_assignee: Kukupa::Models::User[@task.assigned_to],
        task_content: @task.decrypt(:content),
        urls: {
          complete: url("/case/#{@case.id}/task/#{@task.id}/complete"),
        },
      })
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    unless @content
      flash :error, t(:'case/task/edit/edit/errors/no_content')
      return redirect request.path
    end

    # get assignee
    @assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless case_user_can_access?(@case, @assignee)
      flash :error, t(:'case/task/edit/edit/errors/invalid_user')
      return redirect request.path
    end

    if @assignee.id != @task.assigned_to
      # if assignee changing, create update entry
      update_entry = Kukupa::Models::CaseTaskUpdate.new(
        task: @task.id,
        author: @user.id,
      ).save

      update_entry.encrypt(:update_type, 'assign')
      update_entry.encrypt(:data, JSON.generate(to: @assignee.id))
      update_entry.save

      # TODO: if assignee changing, send "new task" email to the new assignee
    end

    # save task
    @task.assigned_to = @assignee.id
    @task.encrypt(:content, @content)
    @task.save

    # redirect back
    flash :success, t(:'case/task/edit/edit/success')
    redirect request.path
  end

  def complete(cid, tid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @task = Kukupa::Models::CaseTask[tid.to_i]
    return halt 404 unless @task
    return halt 404 unless @task.case == @case.id

    unless @task.completion.nil?
      flash :error, t(:'case/task/edit/complete/errors/already_complete')
      return redirect url("/case/#{@case.id}/task/#{@task.id}")
    end

    # set completion
    @task.completion = DateTime.now
    @task.save

    # create update entry
    update_entry = Kukupa::Models::CaseTaskUpdate.new(
      task: @task.id,
      author: @user.id,
    ).save

    update_entry.encrypt(:update_type, 'complete')
    update_entry.save

    flash :success, t(:'case/task/edit/complete/success', task_id: @task.id, ts: update_entry.creation)
    redirect url("/case/#{@case.id}/view##{update_entry.anchor}")
  end
end
