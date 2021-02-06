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
    return halt 404 unless @case && @case.is_open
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
    @note.send_creation_email!

    # redirect back
    flash :success, t(:'case/note/add/success')
    redirect url("/case/#{@case.id}/view##{@note.anchor}")
  end
end
