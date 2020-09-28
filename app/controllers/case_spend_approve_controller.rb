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
    @content = @spend.decrypt(:notes)
    @amount = @spend.decrypt(:amount).to_f
    @author = Kukupa::Models::User[@spend.author]
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
      })
    end

    unless request.params['approve'].to_i.positive?
      return redirect request.path
    end

    @spend.approved = Time.now.utc
    @spend.approver = @user.id
    @spend.save

    # send email to spend author and case assigned advocate
    # saying the spend has been approved
    to_email = [@spend.author, @case.assigned_advocate].uniq
    to_email.reject! { |x| x == @user.id }
    unless to_email.empty?
      case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      case_url += "/case/#{@case.id}/view"

      @email = Kukupa::Models::EmailQueue.new_from_template("spend_approved", {
        case_obj: @case,
        case_url: case_url.to_s,
        spend_obj: @spend,
        content: @content,
        amount: @amount,
        author: @author,
        approver: @user,
      })

      @email.encrypt(:subject, "Spend approved") # TODO: tl this
      @email.encrypt(:recipients, JSON.generate({
        "mode": "list_uids",
        "uids": to_email,
      }))

      @email.queue_status = 'queued'
      @email.save
    end

    flash :success, t(:'case/spend/approve/success', spend_id: @spend.id, amount: @spend.decrypt(:amount).to_f)
    return redirect url("/case/#{@case.id}/view")
  end
end
