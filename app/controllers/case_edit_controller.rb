require 'chronic'

class Kukupa::Controllers::CaseEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/prison', method: :prison
  add_route :post, '/assign', method: :assign
  add_route :post, '/unassign', method: :unassign
  add_route :post, '/create-triage-task', method: :create_triage_task
  add_route :post, '/reset-triage-task', method: :reset_triage_task
  add_route :post, '/close-case', method: :close_case
  add_route :get, '/open-case', method: :open_case
  add_route :post, '/open-case', method: :open_case

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::ReconnectHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user

    @prisons = Kukupa::Models::Prison.get_prisons
    @assignable_users = case_assignable_users
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @case_name = @case.get_name
    @title = t(:'case/edit/title', name: @case_name, casetype: @case.type)

    @prison = Kukupa::Models::Prison[@case.decrypt(:prison).to_i]
    @first_name = @case.decrypt(:first_name)
    @middle_name = @case.decrypt(:middle_name)
    @last_name = @case.decrypt(:last_name)
    @pseudonym = @case.decrypt(:pseudonym)
    @prn = @case.decrypt(:prisoner_number)
    @birth_date = @case.decrypt(:birth_date)
    @birth_date = Chronic.parse(@birth_date, guess: true) if @birth_date
    @release_date = @case.decrypt(:release_date)
    @release_date = Chronic.parse(@release_date, guess: true) if @release_date
    @global_note = @case.decrypt(:global_note)
    @case_purpose = @case.purpose
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    @case_is_new = @case.creation > Chronic.parse(Kukupa.app_config['case-new-threshold'])
    @case_triage_task = Kukupa::Models::CaseTask[@case.triage_task]

    @assigned = @case.get_assigned_advocates.map do |aa|
      user = Kukupa::Models::User[aa]
      next nil unless user

      {
        obj: user,
        id: user.id,
        name: user.decrypt(:name),
        tags: user.roles.map{|r| /tag\:(\w+)/.match(r)&.[](1)}.compact.uniq,
      }
    end.compact

    @suggested_advocates = Kukupa::Models::PrisonAssignee.where(prison: @prison&.id).map do |pa|
      user = Kukupa::Models::User[pa.user]
      next nil unless user

      is_assigned = @assigned
        .filter { |u| u[:id] == user.id }
        .count
        .positive?

      next nil if is_assigned

      {
        id: user.id,
        name: user.decrypt(:name),
        tags: user.roles.map{|r| /tag\:(\w+)/.match(r)&.[](1)}.compact.uniq,
      }
    end.compact

    if request.post?
      @first_name = request.params['first_name']&.strip
      @first_name = nil if @first_name&.empty?
      @middle_name = request.params['middle_name']&.strip
      @middle_name = nil if @middle_name&.empty?
      @last_name = request.params['last_name']&.strip
      @last_name = nil if @last_name&.empty?
      @pseudonym = request.params['pseudonym']&.strip
      @pseudonym = nil if @pseudonym&.empty?
      @birth_date = Chronic.parse(request.params['birth_date']&.strip, guess: true)
      @release_date = Chronic.parse(request.params['release_date']&.strip, guess: true)
      @global_note = request.params['global_note']&.strip
      @global_note = Sanitize.fragment(@global_note, Sanitize::Config::RELAXED)
      @case_purpose = request.params['purpose']&.strip&.downcase
      @case_purpose = Kukupa::Models::Case::ALLOWED_PURPOSES.first if @case_purpose.nil? || @case_purpose&.empty?
      @is_private = request.params['is_private']&.strip&.downcase == 'on'

      if @case.type == 'case'
        if @first_name.nil? || @last_name.nil?
          flash :error, t(:'case/edit/edit/errors/missing_required')
          return redirect request.path
        end

        unless Kukupa::Models::Case::ALLOWED_PURPOSES.include?(@case_purpose)
          flash :error, t(:'case/edit/edit/errors/missing_required')
          return redirect request.path
        end

        # normal cases are always private
        @is_private = true

      elsif @case.type == 'project'
        if @first_name.nil?
          flash :error, t(:'case/edit/edit/errors/missing_required')
          return redirect request.path
        end

      else
        flash :error, t(:'case/edit/edit/errors/invalid_type')
        return redirect request.path
      end

      @case.encrypt(:first_name, @first_name)
      @case.encrypt(:middle_name, @middle_name)
      @case.encrypt(:last_name, @last_name)
      @case.encrypt(:pseudonym, @pseudonym)
      @case.encrypt(:birth_date, @birth_date&.strftime('%Y-%m-%d'))
      @case.encrypt(:release_date, @release_date&.strftime('%Y-%m-%d'))
      @case.encrypt(:global_note, @global_note)
      @case.purpose = @case_purpose
      @case.is_private = @is_private
      @case.save

      Kukupa::Models::CaseFilter.clear_filters_for(@case)
      Kukupa::Models::CaseFilter.create_filters_for(@case)

      flash :success, t(:'case/edit/edit/success')
    end

    return haml(:'case/edit/index', :locals => {
      cuser: @user,
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_assigned: @assigned,
      case_prison: @prison,
      case_editables: {
        first_name: @first_name,
        middle_name: @middle_name,
        last_name: @last_name,
        pseudonym: @pseudonym,
        prn: @prn,
        birth_date: @birth_date,
        release_date: @release_date,
        global_note: @global_note,
        case_purpose: @case_purpose,
      },
      case_reconnect: {
        id: @reconnect_id,
        data: @reconnect_data,
        name: @reconnect_data ? @reconnect_data['name']&.compact&.join(' ') : nil,
      },
      case_is_new: @case_is_new,
      case_triage_task: @case_triage_task,
      assignable_users: @assignable_users,
      assignable_suggested: @suggested_advocates,
      prisons: @prisons,
    })
  end

  def prison(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    return halt 404 unless @case.type == 'case'
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @prison = request.params['prison']&.strip&.downcase
    if ['unknown', 'nil', ''].include?(@prison)
      @prison = nil
    else
      @prison = Kukupa::Models::Prison[@prison.to_i]

      unless @prison
        flash :error, t(:'case/edit/prison/errors/invalid_prison')
        return redirect back
      end
    end

    @prn = request.params['prn']&.strip&.downcase
    Kukupa::Models::CaseFilter.perform_filter(:prisoner_number, @prn).each do |cf|
      if cf.case != @case.id
        flash :error, t(:'case/edit/prison/errors/prn_exists')
        return redirect back
      end
    end

    # save details
    @case.encrypt(:prison, @prison&.id&.to_s)
    @case.encrypt(:prisoner_number, @prn)
    @case.save
    
    Kukupa::Models::CaseFilter.clear_filters_for(@case)
    Kukupa::Models::CaseFilter.create_filters_for(@case)

    flash :success, t(:'case/edit/prison/success')
    redirect back
  end

  def assign(cid)
    return halt 404 unless has_role?('case:assignees:assign')
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open

    @new_assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless @new_assignee || @assignable_users.keys.include?(@new_assignee.id.to_s)
      flash :error, t(:'case/edit/assignees/assign/errors/invalid_user')
      return redirect back
    end
    
    if @case.get_assigned_advocates.include?(@new_assignee.id)
      flash :error, t(:'case/edit/assignees/assign/errors/user_already_assigned')
      return redirect back
    end
    
    if @new_assignee.is_at_case_limit?
      flash :error, t(:'case/edit/assignees/assign/errors/user_over_case_load_limit')
      return redirect back
    end

    assign = Kukupa::Models::CaseAssignedAdvocate
      .new(case: @case.id, user: @new_assignee.id)
      .save

    # send an email to the assignee telling them they have a new case
    assign.send_new_assignee_email!

    flash :success, t(:'case/edit/assignees/assign/success', name: @new_assignee.decrypt(:name))
    redirect back
  end
  
  def unassign(cid)
    return halt 404 unless has_role?('case:assignees:unassign')
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open

    @assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless @new_assignee || @case.get_assigned_advocates.include?(@assignee.id)
      flash :error, t(:'case/edit/assignees/unassign/errors/invalid_user')
      return redirect back
    end

    Kukupa::Models::CaseAssignedAdvocate
      .where(case: @case.id, user: @assignee.id)
      .first
      .delete!

    flash :success, t(:'case/edit/assignees/unassign/success', name: @assignee.decrypt(:name))
    redirect back
  end

  def create_triage_task(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    return halt 404 unless @case.type == 'case'
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    # bail if we already have a triage task
    unless @case.triage_task.nil?
      flash :warning, t(:'case/edit/triage_task/errors/already_exists')
      return redirect back
    end

    # get the assignee from the query params, bail if the user doesn't exist
    @assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless @assignee
      flash :error, t(:'case/edit/triage_task/errors/invalid_user')
      return redirect back
    end

    # create the task
    @task = Kukupa::Models::CaseTask.new(
      case: @case.id,
      author: nil,
      assigned_to: @assignee.id,
    ).save

    @task.encrypt(:content, t(
      :'case/edit/triage_task/task_message',
      force_language: true,
    ))
    @task.save
 
    # save the triage task ID on the case
    @case.triage_task = @task.id
    @case.save

    # send "new task" email to the assigned advocate for this task
    @task.send_creation_email!

    flash :success, t(
      :'case/edit/triage_task/success',
      name: @assignee.decrypt(:name) || t(:'unknown'),
    )

    return redirect back
  end

  def reset_triage_task(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    return halt 404 unless @case.type == 'case'
    return halt 404 unless has_role?('case:triage:reset')
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    unless request.params['confirm']&.strip&.downcase == 'on'
      flash :error, t(:'case/edit/triage_task/reset/errors/confirm_not_checked')
      return redirect back
    end

    @case.triage_task = nil
    @case.save

    flash :success, t(:'case/edit/triage_task/reset/success')
    return redirect back
  end

  def close_case(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    unless request.params['confirm']&.strip&.downcase == 'on'
      flash :error, t(:'case/edit/close_case/errors/confirm_not_checked')
      return redirect back
    end

    @case.close!

    flash :success, t(:'case/edit/close_case/success')
    return redirect url("/case")
  end

  def open_case(cid)
    return halt 404 unless has_role?("case:reopen")

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    if @case.is_open
      return redirect url("/case/#{@case.id}/view")
    end

    @case_name = @case.get_name
    @title = t(:'case/edit/open_case/title', name: @case_name)

    if request.post?
      @case.is_open = true
      @case.save
  
      flash :success, t(:'case/edit/open_case/success')
      return redirect url("/case/#{@case.id}/view")
    end

    haml(:'case/edit/reopen', locals: {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
    })
  end
end
