require 'sanitize'

class Kukupa::Controllers::CaseNoteAddController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @case_name = @case.get_name
    @title = t(:'case/note/add/title', name: @case_name)

    if request.get?
      return haml(:'case/note/add', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
      })
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    unless @content
      flash :error, t(:'case/note/add/errors/no_content')
      return redirect request.path
    end

    # run a sanitize pass
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)

    # create note
    @note = Kukupa::Models::CaseNote.new(case: @case.id, author: @user.id).save
    @note.encrypt(:content, @content)
    @note.save

    # send "new note" email to the assigned advocate for this case
    # if the assigned advocate was not the one that created this case note
    unless @user.id == @case.assigned_advocate
      note_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      note_url += "/case/#{@case.id}/view##{@note.anchor}"

      @email = Kukupa::Models::EmailQueue.new_from_template("note_new", {
        case_obj: @case,
        note_obj: @note,
        note_url: note_url.to_s,
        content: @content,
        author: @user,
      })

      @email.encrypt(:subject, "Case note added") # TODO: tl this
      @email.encrypt(:recipients, JSON.generate({
        "mode": "list_uids",
        "uids": [@case.assigned_advocate],
      }))

      @email.queue_status = 'queued'
      @email.save
    end

    # redirect back
    flash :success, t(:'case/note/add/success')
    redirect url("/case/#{@case.id}/view##{@note.anchor}")
  end
end
