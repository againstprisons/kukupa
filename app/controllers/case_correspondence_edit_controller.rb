class Kukupa::Controllers::CaseCorrespondenceEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/delete', method: :delete
  add_route :get, '/approve', method: :approve
  add_route :post, '/approve', method: :approve

  include Kukupa::Helpers::CaseViewHelpers

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end
  end

  def index(cid, ccid)
    @cc_obj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @cc_obj
    return halt 404 unless @cc_obj.case == @case.id

    @cc_edit_content = false
    if has_role?("case:correspondence:edit_content")
      @cc_edit_content = !@cc_obj.has_been_sent
    end

    @cc_subject = @cc_obj.decrypt(:subject)
    @case_name = @case.get_name
    @title = t(:'case/correspondence/edit/title', ccid: @cc_obj.id, name: @case_name)

    if @cc_edit_content && @cc_obj.file_type == 'local'
      @cc_content = @cc_obj.get_file_content__local
    end

    if request.post?
      @cc_subject = request.params['subject']&.strip
      @cc_subject = nil if @cc_subject&.empty?
      @cc_obj.encrypt(:subject, @cc_subject)

      if @cc_edit_content && @cc_obj.file_type == 'local'
        @cc_content = request.params['content']&.strip
        @cc_content = Sanitize.fragment(@cc_content, Sanitize::Config::RELAXED)

        file = Kukupa::Models::File.where(file_id: @cc_obj.file_id).first
        file.replace(
          "kukupa_emailedit_#{DateTime.now.strftime('%s')}.html",
          @cc_content,
        )
        file.save
      end

      @cc_obj.save
      flash :success, t(:'case/correspondence/edit/edit/success')
    end

    return haml(:'case/correspondence/edit/index', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      renderables: renderable_post_process(@cc_obj.renderables),
      cc_obj: @cc_obj,
      cc_subject: @cc_subject,
      cc_content: @cc_content,
      cc_edit_content: @cc_edit_content,
      cc_approved: @cc_obj.approved,
      urls: {
        approve: url("/case/#{@case.id}/correspondence/#{@cc_obj.id}/approve"),
        delete: url("/case/#{@case.id}/correspondence/#{@cc_obj.id}/delete"),
      }
    })
  end
  
  def delete(cid, ccid)
    return halt 404 unless has_role?('case:delete_entry')

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

  def approve(cid, ccid)
    return halt 404 unless has_role?('case:correspondence:can_approve')

    @cc_obj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @cc_obj
    return halt 404 unless @cc_obj.case == @case.id
    return halt 418 if @cc_obj.approved

    if request.post?
      @cc_obj.update(approved: true, approved_by: current_user.id)

      result = @cc_obj.send_correspondence_to_target!
      if result == true
        @cc_obj.create_outgoing_print_task!
        flash :success, t(:'case/correspondence/approve/success')
        return redirect url("/case/#{@case.id}/view##{@cc_obj.anchor}")

      else
        flash :success, t(:'case/correspondence/approve/errors/send_failed', error: result.inspect)
        @cc_obj.update(approved: false)
      end
    end

    @cc_content = @cc_obj.get_file_content
    @cc_subject = @cc_obj.decrypt(:subject)
    @case_name = @case.get_name
    @title = t(:'case/correspondence/approve/title', ccid: @cc_obj.id, name: @case_name)

    return haml(:'case/correspondence/edit/approve', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      cc_obj: @cc_obj,
      cc_type: @cc_obj.correspondence_type,
      cc_email: @cc_obj.decrypt(:target_email),
      cc_subject: @cc_subject,
      cc_content: @cc_content,
    })
  end
end
