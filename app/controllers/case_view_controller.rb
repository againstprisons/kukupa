class Kukupa::Controllers::CaseViewController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseViewHelpers

  def before(cid)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    if has_role?('case:view_all')
      @can_edit = true
    else
      return halt 404 unless @case.can_view?(@user)
      @can_edit = @case.can_access?(@user)
    end

    @show = Kukupa::Models::Case::CASE_TYPES[@case.type.to_sym][:show]
  end

  def index(cid)
    @case_name = @case.get_name
    @title = t(:'case/view/title', name: @case_name, casetype: @case.type)

    @renderable_updates = request.params['ru'].to_i.positive?
    @renderables = get_renderables(@case, {
      include_updates: @renderable_updates,
      renderable_opts: {
        spend_can_approve: has_role?('case:spend:can_approve'),
      }
    })

    @tasks_complete = request.params['tc'].to_i.positive?
    @tasks = get_tasks(@case, include_complete: @tasks_complete)

    @prison = Kukupa::Models::Prison[@case.decrypt(:prison).to_i]
    if @prison && @case.prisoner_number
      p_addr = @prison.decrypt(:physical_address)
      p_addr = p_addr&.split("\n")&.map(&:strip)
      unless p_addr.nil? || p_addr&.empty?
        @address = [
          @case_name,
          "PRN #{@case.decrypt(:prisoner_number)&.strip}",
          p_addr,
        ].join(', ')
      end
    end

    @this_url = Addressable::URI.parse(url(request.path))
    @this_url.query_values = {
      'tc' => @tasks_complete ? '1' : '0',
      'ru' => @renderable_updates ? '1' : '0',
     }

    @renderable_updates_toggle = @this_url.dup
    @renderable_updates_toggle.query_values = {
      'tc' => @tasks_complete ? '1' : '0',
      'ru' => @renderable_updates ? '0' : '1',
    }

    @tasks_complete_toggle = @this_url.dup
    @tasks_complete_toggle.query_values = {
      'tc' => @tasks_complete ? '0' : '1',
      'ru' => @renderable_updates ? '1' : '0',
    }

    @spend_year_max = Kukupa.app_config['fund-max-spend-per-case-year'].to_f
    @spend_year = Kukupa::Models::CaseSpendAggregate.get_case_year_total(@case, DateTime.now)
    @spend_year_percent = @spend_year / @spend_year_max
    
    @global_note = @case.decrypt(:global_note)
    @global_note = nil if @global_note&.strip&.empty?

    @case_is_new = @case.creation > Chronic.parse(Kukupa.app_config['case-new-threshold'])
    @case_triage_task = Kukupa::Models::CaseTask[@case.triage_task.to_i]

    @case_assigned_advocates = @case
      .get_assigned_advocates
      .map {|u| Kukupa::Models::User[u]}
      .map {|u| [u.id, u.decrypt(:name)]}

    return haml(:'case/view', :locals => {
      title: @title,
      cuser_can_edit: @can_edit,
      case_obj: @case,
      case_show: @show,
      case_open: @case.is_open,
      case_name: @case_name,
      case_prison: @prison,
      case_address: @address,
      case_global_note: @global_note,
      case_duration: @case.duration,
      case_purpose: @case.purpose,
      case_is_new: @case_is_new,
      case_triage_task: @case_triage_task,
      case_assigned_advocates: @case_assigned_advocates,
      renderables: @renderables,
      renderable_updates: @renderable_updates,
      renderable_updates_toggle: @renderable_updates_toggle,
      tasks: @tasks,
      tasks_complete: @tasks_complete,
      tasks_complete_toggle: @tasks_complete_toggle,
      spend_year: @spend_year,
      spend_year_max: @spend_year_max,
      spend_year_percent: @spend_year_percent,
    })
  end
end
