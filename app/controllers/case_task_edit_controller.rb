class Kukupa::Controllers::CaseTaskEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/complete', method: :complete
  add_route :post, '/delete', method: :delete

  include Kukupa::Helpers::CaseHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid, tid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
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
        current_user: @user,
        case_obj: @case,
        case_name: @case_name,
        case_accessors: @accessors,
        task_obj: @task,
        task_assignee: Kukupa::Models::User[@task.assigned_to],
        task_content: @task.decrypt(:content),
        urls: {
          complete: url("/case/#{@case.id}/task/#{@task.id}/complete"),
          delete: url("/case/#{@case.id}/task/#{@task.id}/delete"),
        },
      })
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED) if @content
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
        update_type: 'assign',
      ).save

      update_entry.encrypt(:data, JSON.generate(to: @assignee.id))
      update_entry.save

      # if assignee changing, send "new task" email to the new assignee
      case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      case_url += "/case/#{@case.id}/view"

      @email = Kukupa::Models::EmailQueue.new_from_template("task_new", {
        case_obj: @case,
        case_url: case_url.to_s,
        task_obj: @task,
        content: @content,
        assignee: @assignee,
      })

      @email.encrypt(:subject, "New task assigned to you") # TODO: tl this
      @email.encrypt(:recipients, JSON.generate({
        "mode": "list_uids",
        "uids": [
          @assignee.id,
        ],
      }))

      @email.queue_status = 'queued'
      @email.save
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
      return halt 404 unless @case.can_access?(@user)
    end

    @task = Kukupa::Models::CaseTask[tid.to_i]
    return halt 404 unless @task
    return halt 404 unless @task.case == @case.id

    unless @user.id == @task.assigned_to || @user.id == @task.author
      flash :error, t(:'case/task/edit/complete/errors/not_author')
      return redirect url("/case/#{@case.id}/task/#{@task.id}")
    end

    unless @task.completion.nil?
      flash :error, t(:'case/task/edit/complete/errors/already_complete')
      return redirect url("/case/#{@case.id}/task/#{@task.id}")
    end

    # set completion
    @task.completion = Time.now.utc
    @task.save

    # create update entry
    update_entry = Kukupa::Models::CaseTaskUpdate.new(
      task: @task.id,
      author: @user.id,
      update_type: 'complete',
    ).save

    # TODO: send "task complete" email to this task's author and assignee
    # if the author or assignee is not the user completing the task

    flash :success, t(:'case/task/edit/complete/success', task_id: @task.id, ts: update_entry.creation)
    redirect url("/case/#{@case.id}/view##{update_entry.anchor}")
  end

  def delete(cid, tid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @task = Kukupa::Models::CaseTask[tid.to_i]
    return halt 404 unless @task
    return halt 404 unless @task.case == @case.id

    unless @user.id == @task.assigned_to || @user.id == @task.author
      flash :error, t(:'case/task/edit/delete/errors/not_author')
      return redirect url("/case/#{@case.id}/task/#{@task.id}")
    end

    unless request.params['confirm']&.strip == "DELETE"
      flash :error, t(:'case/task/edit/delete/errors/no_confirm')
      return redirect url("/case/#{@case.id}/task/#{@task.id}")
    end

    # TODO: send "task deleted" email to this task's author and assignee
    # if the author or assignee is not the user deleting the task

    # perform deletion
    Kukupa::Models::CaseTaskUpdate.where(task: @task.id).delete
    @task.delete

    # redirect back
    flash :success, t(:'case/task/edit/delete/success', task_id: @task.id)
    redirect url("/case/#{@case.id}/view")
  end
end
