class Kukupa::Controllers::CaseViewController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseViewHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @case_name = @case.get_name
    @title = t(:'case/view/title', name: @case_name)
    @renderables = get_renderables(@case)
    @tasks_complete = request.params['tc'].to_i.positive?
    @tasks = get_tasks(@case, include_complete: @tasks_complete)

    @spend_year_max = Kukupa.app_config['fund-max-spend-per-case-year'].to_f
    @spend_year = Kukupa::Models::CaseSpendAggregate.get_case_year_total(@case, DateTime.now)
    @spend_year_percent = @spend_year / @spend_year_max

    return haml(:'case/view', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      renderables: @renderables,
      tasks: @tasks,
      tasks_complete: @tasks_complete,
      spend_year: @spend_year,
      spend_year_max: @spend_year_max,
      spend_year_percent: @spend_year_percent,
    })
  end
end
