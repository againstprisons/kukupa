class Kukupa::Controllers::CaseCorrespondenceEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/delete', method: :delete

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid, ccid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @cc_obj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @cc_obj
    return halt 404 unless @cc_obj.case == @case.id

    @cc_subject = @cc_obj.decrypt(:subject)
    @case_name = @case.get_name
    @title = t(:'case/correspondence/edit/title', ccid: @cc_obj.id, name: @case_name)

    if request.post?
      @cc_subject = request.params['subject']&.strip
      @cc_subject = nil if @cc_subject&.empty?

      @cc_obj.encrypt(:subject, @cc_subject)
      @cc_obj.save

      flash :success, t(:'case/correspondence/edit/edit/success')
    end

    return haml(:'case/correspondence/edit', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      cc_obj: @cc_obj,
      cc_subject: @cc_subject,
      urls: {
        delete: url("/case/#{@case.id}/correspondence/#{@cc_obj.id}/delete"),
      }
    })
  end
  
  def delete(cid, ccid)
    return halt 404 unless has_role?('case:delete_entry')
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case && @case.is_open

    @cc_obj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @cc_obj
    return halt 404 unless @cc_obj.case == @case.id

    unless request.params['confirm']&.strip == "DELETE"
      flash :error, t(:'case/correspondence/edit/delete/errors/no_confirm')
      return redirect url("/case/#{@case.id}/correspondence/#{@cc_obj.id}")
    end

    @cc_obj.send_deletion_email!(@user)
    @cc_obj.delete!

    flash :success, t(:'case/correspondence/edit/delete/success', ccid: @cc_obj.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
