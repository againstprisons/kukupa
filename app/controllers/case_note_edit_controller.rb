require 'sanitize'

class Kukupa::Controllers::CaseNoteEditController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :get, '/file', method: :file
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

  def index(cid, nid)
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

    # create a CaseNoteUpdate with the edited content
    @note_update = Kukupa::Models::CaseNoteUpdate.new(
      note: @note.id,
      author: @user.id,
      update_type: 'edit',
    ).save

    @note_update.encrypt(:data, JSON.generate({
      old_content: @note.decrypt(:content),
      new_content: @content,
    }))

    @note_update.save

    # send note edit email
    @note.send_creation_email!(edited: true)

    # save
    @note.edited = @note_update.creation
    @note.encrypt(:content, @content)
    @note.save

    flash :success, t(:'case/note/edit/edit/success')
    return redirect request.path
  end

  def file(cid, nid)
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case

    @note = Kukupa::Models::CaseNote[nid.to_i]
    return halt 404 unless @note
    return halt 404 unless @note.case == @case.id

    file_id = @note.decrypt(:file_id)
    @file = Kukupa::Models::File.where(file_id: file_id).first
    return halt 404 unless @file

    @dl_token = @file.generate_download_token(@user)
    @url_dl = url("/filedl/#{@file.file_id}/#{@dl_token.token}")
    return redirect @url_dl
  end

  def delete(cid, nid)
    return halt 404 unless has_role?('case:delete_entry')
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case && @case.is_open

    @note = Kukupa::Models::CaseNote[nid.to_i]
    return halt 404 unless @note
    return halt 404 unless @note.case == @case.id

    unless request.params['confirm']&.strip == "DELETE"
      flash :error, t(:'case/note/edit/delete/errors/no_confirm')
      return redirect url("/case/#{@case.id}/note/#{@note.id}")
    end

    @note.send_deletion_email!(@user)
    @note.delete!

    flash :success, t(:'case/note/edit/delete/success', note_id: @note.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
