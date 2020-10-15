require 'chronic'

class Kukupa::Controllers::CaseEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/prison', method: :prison
  add_route :post, '/assign', method: :assign

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
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

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
    @assigned = Kukupa::Models::User[@case.assigned_advocate]
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    @case_name = @case.get_name
    @title = t(:'case/edit/title', name: @case_name)

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

      if @first_name.nil? || @last_name.nil?
        flash :error, t(:'case/edit/edit/errors/missing_required')
        return redirect request.path
      end

      @case.encrypt(:first_name, @first_name)
      @case.encrypt(:middle_name, @middle_name)
      @case.encrypt(:last_name, @last_name)
      @case.encrypt(:pseudonym, @pseudonym)
      @case.encrypt(:birth_date, @birth_date&.strftime('%Y-%m-%d'))
      @case.encrypt(:release_date, @release_date&.strftime('%Y-%m-%d'))
      @case.save

      flash :success, t(:'case/edit/edit/success')
    end

    return haml(:'case/edit/index', :locals => {
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
      },
      case_reconnect: {
        id: @reconnect_id,
        data: @reconnect_data,
        name: @reconnect_data ? @reconnect_data['name']&.compact&.join(' ') : nil,
      },
      assignable_users: @assignable_users,
      prisons: @prisons,
    })
  end

  def prison(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
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

    flash :success, t(:'case/edit/prison/success')
    redirect back
  end

  def assign(cid)
    return halt 404 unless has_role?('case:assign')
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case

    @new_assignee = Kukupa::Models::User[request.params['assignee'].to_i]
    unless @new_assignee || @assignable_users.keys.include?(@new_assignee.id.to_s)
      flash :error, t(:'case/edit/assign/errors/invalid_user')
      return redirect back
    end

    @case.assigned_advocate = @new_assignee.id
    @case.save

    flash :success, t(:'case/edit/assign/success', name: @new_assignee.decrypt(:name))
    redirect back
  end
end
