class Kukupa::Controllers::CaseViewController < Kukupa::Controllers::CaseController
  add_route :get, '/'

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

    @spend_year = Kukupa::Models::CaseSpendYear
      .get_case_year(@case, DateTime.now)
      &.decrypt(:amount)
      &.to_f || 0.0

    @spend_year_percent = (
      @spend_year / (Kukupa.app_config['fund-max-spend-per-case-year'].to_f)
    )

    return haml(:'case/view', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      spend_year: @spend_year,
      spend_year_percent: @spend_year_percent,
    })
  end
end
