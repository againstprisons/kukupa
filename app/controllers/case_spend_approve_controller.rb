class Kukupa::Controllers::CaseSpendApproveController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end
  end

  def index(cid, sid)
    @spend = Kukupa::Models::CaseSpend[sid.to_i]
    return halt 404 unless @spend
    return halt 404 unless @spend.case == @case.id
    unless @spend.approver.nil?
      flash :warning, t(:'case/spend/approve/errors/already_approved')
      return redirect url("/case/#{@case.id}/spend/#{@spend.id}")
    end

    @content = @spend.decrypt(:notes)
    @amount = @spend.decrypt(:amount).to_f
    @author = Kukupa::Models::User[@spend.author]
    @reimbursement_info = @spend.decrypt(:reimbursement_info)
    
    receipt_file = @spend.decrypt(:receipt_file)
    if receipt_file
      @receipt = Kukupa::Models::File.where(file_id: receipt_file).first
    end

    @case_name = @case.get_name
    @title = t(:'case/spend/approve/title', name: @case_name, spend_id: @spend.id)

    if request.get?
      return haml(:'case/spend/approve', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        spend_obj: @spend,
        spend_notes: @content,
        spend_amount: @amount,
        spend_author: @author,
        spend_author_self: @author.id == @user.id,
        spend_reimbursement: @spend.is_reimbursement,
        spend_reimbursement_info: @reimbursement_info,
        spend_receipt: @receipt,
      })
    end

    unless request.params['approve'].to_i.positive?
      return redirect request.path
    end

    # save details
    @spend.approved = Sequel.function(:NOW)
    @spend.approver = @user.id
    @spend.save

    # send spend-approved email
    @spend.send_approve_email!

    # update aggregate 
    Kukupa::Models::CaseSpendAggregate.create_aggregate_for_case(@case)

    flash :success, t(:'case/spend/approve/success', spend_id: @spend.id, amount: @spend.decrypt(:amount).to_f)
    return redirect url("/case/#{@case.id}/view")
  end
end
