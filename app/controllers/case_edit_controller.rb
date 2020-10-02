require 'chronic'

class Kukupa::Controllers::CaseEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/prison', method: :prison
  add_route :post, '/assign', method: :assign

  include Kukupa::Helpers::CaseHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user

    @assignable_users = case_assignable_users
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

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
    @case_name = @case.get_name
    @title = t(:'case/edit/title', name: @case_name)

    if request.post?
      @first_name = request.params['first_name']&.strip
      @middle_name = request.params['middle_name']&.strip
      @last_name = request.params['last_name']&.strip
      @pseudonym = request.params['pseudonym']&.strip
      @birth_date = Chronic.parse(request.params['birth_date']&.strip, guess: true)
      @release_date = Chronic.parse(request.params['release_date']&.strip, guess: true)

      @case.encrypt(:first_name, @first_name)
      @case.encrypt(:middle_name, @middle_name)
      @case.encrypt(:last_name, @last_name)
      @case.encrypt(:pseudonym, @pseudonym)
      @case.encrypt(:birth_date, @birth_date&.strftime('%Y-%m-%d'))
      @case.encrypt(:release_date, @release_date&.strftime('%Y-%m-%d'))
      @case.save

      flash :success, t(:'case/edit/edit/success')
    end

    return haml(:'case/edit', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_assigned: @assigned,
      case_editables: {
        first_name: @first_name,
        middle_name: @middle_name,
        last_name: @last_name,
        pseudonym: @pseudonym,
        prn: @prn,
        birth_date: @birth_date,
        release_date: @release_date,
      },
      assignable_users: @assignable_users,
    })
  end

  def prison(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @prison = request.params['prison']&.strip&.downcase
    if @prison == 'unknown'
      @prison = nil
    else
      # TODO: once we have a list of prisons, allow changing what prison
      # a case resides in
      # @prison = Kukupa::Models::Prison[@prison.to_i]

      return halt 501 # TODO: remove this

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
    @case.encrypt(:prison, @prison)
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
    unless @new_assignee
      flash :error, t(:'case/edit/assign/errors/invalid_user')
      return redirect back
    end

    @case.assigned_advocate = @new_assignee.id
    @case.save

    flash :success, t(:'case/edit/assign/success', name: @new_assignee.decrypt(:name))
    redirect back
  end
end
