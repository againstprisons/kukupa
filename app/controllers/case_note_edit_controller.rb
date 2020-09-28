require 'sanitize'

class Kukupa::Controllers::CaseNoteEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :post, '/delete', method: :delete

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid, nid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @note = Kukupa::Models::CaseNote[nid.to_i]
    return halt 404 unless @note
    return halt 404 unless @note.case == @case.id

    @case_name = @case.get_name
    @title = t(:'case/note/edit/title', name: @case_name, note_id: @note.id)

    if request.get?
      return haml(:'case/note/edit', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        note_obj: @note,
        note_content: @note.decrypt(:content),
        urls: {
          delete: url("/case/#{@case.id}/note/#{@note.id}/delete"),
        }
      })
    end

    if @note.is_outside_request
      flash :error, t(:'case/note/edit/edit/errors/outside_request')
      return redirect request.path
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    unless @content
      flash :error, t(:'case/note/edit/edit/errors/no_content')
      return redirect request.path
    end

    # run a sanitize pass
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)

    # save
    @note.edited = Time.now.utc
    @note.encrypt(:content, @content)
    @note.save

    flash :success, t(:'case/note/edit/edit/success')
    return redirect request.path
  end

  def delete(cid, nid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @note = Kukupa::Models::CaseNote[nid.to_i]
    return halt 404 unless @note
    return halt 404 unless @note.case == @case.id

    unless request.params['confirm']&.strip == "DELETE"
      flash :error, t(:'case/note/edit/delete/errors/no_confirm')
      return redirect url("/case/#{@case.id}/note/#{@note.id}")
    end

    @note.delete

    flash :success, t(:'case/note/edit/delete/success', note_id: @note.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
