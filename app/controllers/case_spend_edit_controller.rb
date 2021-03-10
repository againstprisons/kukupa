require 'sanitize'

class Kukupa::Controllers::CaseSpendEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/delete', method: :delete

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

    receipt_file = @spend.decrypt(:receipt_file)
    if receipt_file
      @receipt = Kukupa::Models::File.where(file_id: receipt_file).first
    end

    @case_name = @case.get_name
    @title = t(:'case/spend/edit/title', name: @case_name, spend_id: @spend.id)

    if request.get?
      return haml(:'case/spend/edit', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        spend_obj: @spend,
        spend_notes: @spend.decrypt(:notes),
        spend_amount: @spend.decrypt(:amount).to_f,
        spend_approver: @spend.approver,
        spend_approver_self: @spend.approver == @user.id,
        spend_reimbursement: @spend.is_reimbursement,
        spend_reimbursement_info: @spend.decrypt(:reimbursement_info),
        spend_receipt: @receipt,
        urls: {
          delete: url("/case/#{@case.id}/spend/#{@spend.id}/delete"),
        }
      })
    end

    unless @spend.approver.nil?
      unless @spend.approver == @user.id || has_role?('case:spend:can_approve')
        flash :error, t(:'case/spend/edit/edit/errors/is_approved')
        return redirect request.path
      end
    end

    # get amount
    @amount = request.params['amount']&.strip.to_f
    if @amount < Kukupa.app_config['fund-min-spend']
      flash :error, t(:'case/spend/edit/edit/errors/below_minimum', min: Kukupa.app_config['fund-min-spend'])
      return redirect request.path
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    unless @content
      flash :error, t(:'case/spend/edit/edit/errors/no_content')
      return redirect request.path
    end

    # run a sanitize pass
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)
    
    # is this a reimbursement?
    @reimbursement_info = nil
    @reimbursement = request.params['reimbursement']&.strip&.downcase == "on"
    if @reimbursement
      @reimbursement_info = request.params['reimbursement_info']&.strip || ""
      @reimbursement_info = Sanitize.fragment(@reimbursement_info, Sanitize::Config::RELAXED)
    end

    # replace existing receipt if one was uploaded
    if params[:file]
      begin
        fn = params[:file][:filename]
        params[:file][:tempfile].rewind
        data = params[:file][:tempfile].read
      
        @receipt = Kukupa::Models::File.upload(data, filename: fn)
        @spend.encrypt(:receipt_file, @receipt.file_id)
      rescue
        flash :warning, t(:'case/spend/edit/edit/errors/receipt_upload_failed')
      end
    end

    # create a CaseSpendUpdate with the edited content
    @spend_update_data = {
      old_amount: @spend.decrypt(:amount).to_s,
      new_amount: @amount.to_s,
      old_content: @spend.decrypt(:notes),
      new_content: @content,
      old_reimbursement_info: @spend.decrypt(:reimbursement_info),
      new_reimbursement_info: @reimbursement_info,
    }

    @spend_update = Kukupa::Models::CaseSpendUpdate.new(
      spend: @spend.id,
      author: @user.id,
      update_type: 'edit',
    ).save

    @spend_update.encrypt(:data, JSON.generate(@spend_update_data))
    @spend_update.save

    # save the spend
    @spend.encrypt(:amount, @amount.to_s)
    @spend.encrypt(:notes, @content)
    @spend.is_reimbursement = @reimbursement
    @spend.encrypt(:reimbursement_info, @reimbursement_info)
    @spend.save

    # if <= auto-approve threshold AND aggregate for this year is below max,
    # set approver to self
    if @amount <= Kukupa.app_config['fund-max-auto-approve']
      aggregate = Kukupa::Models::CaseSpendAggregate.get_case_year_total(@case, DateTime.now)
      aggregate += @amount if @spend.approver.nil?

      if aggregate <= Kukupa.app_config['fund-max-spend-per-case-year']
        @spend.approver = @user.id
        @spend.save

        @spend.send_creation_email!(autoapproved: true, edited: true)
      end

    # if > auto-approve threshold, automatically *unapprove* the edit, even if
    # the editor has approve powers
    else
      @spend.approved = nil
      @spend.approver = nil
      @spend.save

      # send "new spending request to be approved" email
      @spend.send_creation_email!(edited: true)
    end

    # regenerate aggregates
    Kukupa::Models::CaseSpendAggregate.create_aggregate_for_case(@case)

    flash :success, t(:'case/spend/edit/edit/success')
    return redirect request.path
  end

  def delete(cid, sid)
    return halt 404 unless has_role?('case:delete_entry')

    @spend = Kukupa::Models::CaseSpend[sid.to_i]
    return halt 404 unless @spend
    return halt 404 unless @spend.case == @case.id

    unless request.params['confirm']&.strip == "DELETE"
      flash :error, t(:'case/note/edit/delete/errors/no_confirm')
      return redirect url("/case/#{@case.id}/spend/#{@spend.id}")
    end

    @spend.send_deletion_email!(@user)
    @spend.delete!

    # regenerate aggregate if approved
    unless @spend.approver.nil?
      Kukupa::Models::CaseSpendAggregate.create_aggregate_for_case(@case)
    end

    flash :success, t(:'case/spend/edit/delete/success', spend_id: @spend.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
