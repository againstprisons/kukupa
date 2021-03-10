class Kukupa::Controllers::PrisonAssigneesController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/assign", method: :assign_self
  add_route :post, "/unassign", method: :unassign_self

  def before(*args)
    unless logged_in?
      session[:after_login] = request.path
      return redirect to "/auth"
    end

    @user = current_user
    return halt 404 unless has_role?("case:assignable")
  end

  def index
    @title = t(:'prison_signup/title')
    @prisons = Kukupa::Models::Prison.map do |pr|
      assignees = Kukupa::Models::PrisonAssignee
        .where(prison: pr.id)
        .map(&:user)

      assignees.map! do |u|
        user = Kukupa::Models::User[u]
        next nil unless user

        {
          id: user.id,
          name: user.decrypt(:name),
        }
      end

      assignees.compact!

      self_assigned = assignees
        .filter { |u| u[:id] == @user.id }
        .count
        .positive?

      {
        id: pr.id,
        name: pr.decrypt(:name),
        assignees: assignees,
        self_assigned: self_assigned,
      }
    end

    haml(:'prison_signup/index', :locals => {
      title: @title,
      cuser: @user,
      prisons: @prisons,
    })
  end

  def unassign_self
    @prison = Kukupa::Models::Prison[request.params['prison'].to_i]
    return halt 404 unless @prison
    @prison_name = @prison.decrypt(:name)

    @assignee = Kukupa::Models::PrisonAssignee
      .where(prison: @prison.id, user: @user.id)
      .first

    return halt 404 unless @assignee

    @assignee.delete

    flash :success, t(:'prison_signup/unassign_self/success', name: @prison_name)
    return redirect url("/prison-assignees")
  end

  def assign_self
    @prison = Kukupa::Models::Prison[request.params['prison'].to_i]
    return halt 404 unless @prison
    @prison_name = @prison.decrypt(:name)

    is_assigned = Kukupa::Models::PrisonAssignee
      .where(prison: @prison.id, user: @user.id)
      .count
      .positive?

    if is_assigned
      flash :error, t(:'prison_signup/assign_self/errors/already_assigned')
      return redirect url("/prison-assignees")
    end

    # create the assignee entry
    @assignee = Kukupa::Models::PrisonAssignee
      .new(prison: @prison.id, user: @user.id)
      .save

    flash :success, t(:'prison_signup/assign_self/success', name: @prison_name)
    return redirect url("/prison-assignees")
  end
end
