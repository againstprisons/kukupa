class Kukupa::Controllers::CaseTaskAddController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  include Kukupa::Helpers::CaseHelpers

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end
  end

  def index(cid)
    @accessors = case_users_with_access(@case)
    @case_name = @case.get_name
    @title = t(:'case/task/add/title', name: @case_name)

    if request.get?
      return haml(:'case/task/add', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        case_accessors: @accessors,
        case_accessors_grouped: case_users_group_by_tag(@accessors),
        default_deadline: Chronic.parse(Kukupa.app_config['task-default-deadline']),
      })
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED) if @content
    unless @content
      flash :error, t(:'case/task/add/errors/no_content')
      return redirect request.path
    end

    # get assignee
    @assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless case_user_can_access?(@case, @assignee)
      flash :error, t(:'case/task/add/errors/invalid_user')
      return redirect request.path
    end

    # get deadline
    @deadline = Chronic.parse(request.params['deadline']&.strip&.downcase, guess: true)
    unless @deadline
      @deadline = Chronic.parse(Kukupa.app_config['task-default-deadline'])
    end

    # create task
    @task = Kukupa::Models::CaseTask.new(
      case: @case.id,
      author: @user.id,
      assigned_to: @assignee.id,
      deadline: @deadline,
    ).save

    @task.encrypt(:content, @content)
    @task.save

    # send "new task" email to the assigned advocate for this task
    @task.send_creation_email!

    # redirect back
    flash :success, t(:'case/task/add/success')
    redirect url("/case/#{@case.id}/view#case-view-tasks")
  end
end
