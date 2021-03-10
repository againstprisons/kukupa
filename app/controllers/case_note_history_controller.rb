require 'sanitize'

class Kukupa::Controllers::CaseNoteHistoryController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  include Kukupa::Helpers::CaseHelpers

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
    @case = Kukupa::Models::Case[cid.to_i]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @note = Kukupa::Models::CaseNote[nid.to_i]
    return halt 404 unless @note
    return halt 404 unless @note.case == @case.id

    @advocates = case_populate_advocate({}, @note.author)
    @note_history = Kukupa::Models::CaseNoteUpdate
      .where(note: @note.id)
      .order(:creation)
      .all

    @note_history.map! do |cnu|
      @advocates = case_populate_advocate(@advocates, cnu.author)

      begin
        data = JSON.parse(cnu.decrypt(:data) || '{}').map do |k, v|
          [k.to_sym, v]
        end.to_h
      rescue
        data = {}
      end

      {
        id: cnu.id,
        obj: cnu,
        creation: cnu.creation,
        author: @advocates[cnu.author.to_s],
        old_content: data[:old_content],
        new_content: data[:new_content],
      }
    end

    @case_name = @case.get_name
    @title = t(:'case/note/history/title', name: @case_name, note: @note.id)

    return haml(:'case/note/history', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      note_obj: @note,
      note_author: @advocates[@note.author.to_s],
      note_history: @note_history,
      note_content: @note.decrypt(:content),
      note_creation: @note.creation,
    })
  end
end
