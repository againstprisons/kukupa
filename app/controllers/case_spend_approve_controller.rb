class Kukupa::Controllers::CaseSpendApproveController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("case:spend:can_approve")
    @user = current_user
  end

  def index(cid, sid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @spend = Kukupa::Models::CaseSpend[sid.to_i]
    return halt 404 unless @spend
    return halt 404 unless @spend.case == @case.id
    unless @spend.approver.nil?
      flash :warning, t(:'case/spend/approve/errors/already_approved')
      return redirect url("/case/#{@case.id}/spend/#{@spend.id}")
    end

    @case_name = @case.get_name
    @title = t(:'case/spend/approve/title', name: @case_name, spend_id: @spend.id)

    if request.get?
      return haml(:'case/spend/approve', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        spend_obj: @spend,
        spend_notes: @spend.decrypt(:notes),
        spend_amount: @spend.decrypt(:amount).to_f,
        spend_author: Kukupa::Models::User[@spend.author],
        spend_author_self: @spend.author == @user.id,
      })
    end

    unless request.params['approve'].to_i.positive?
      return redirect request.path
    end

    @spend.approved = DateTime.now
    @spend.approver = @user.id
    @spend.save

    # TODO: send email to spend author and case assigned advocate
    # saying the spend has been approved

    flash :success, t(:'case/spend/approve/success', spend_id: @spend.id, amount: @spend.decrypt(:amount).to_f)
    return redirect url("/case/#{@case.id}/view")
  end
end