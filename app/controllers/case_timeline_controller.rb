require 'chronic'

class Kukupa::Controllers::CaseTimelineController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :get, '/create', method: :create
  add_route :post, '/create', method: :create
  add_route :get, '/:tlid', method: :edit
  add_route :post, '/:tlid', method: :edit
  add_route :post, '/:tlid/delete', method: :delete

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseTimelineHelpers

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @prisons = Kukupa::Models::Prison.get_prisons

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @show = Kukupa::Models::Case::CASE_TYPES[@case.type.to_sym][:show]
    return halt 404 unless @show[:timeline]
  end

  def index(cid)
    @case_name = @case.get_name
    @title = t(:'case/timeline/title', name: @case_name, casetype: @case.type)

    @entries = timeline_entries_for_case(@case)

    haml(:'case/timeline/index', locals: {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      entries: @entries,
    })
  end

  def create(cid)
    @case_name = @case.get_name
    @title = t(:'case/timeline/create/title', name: @case_name, casetype: @case.type)

    if request.post?
      @date = request.params['date']&.strip&.downcase
      @date = Chronic.parse(@date, guess: true)
      @name = request.params['name']&.strip
      @name = nil if @name&.empty?

      unless @name && @date
        flash :error, t(:'required_not_provided')
        return redirect request.path
      end

      @description = request.params['description']&.strip
      @description = Sanitize.fragment(@description, Sanitize::Config::RELAXED)
      @description = nil if @description&.strip&.empty?

      @tl = Kukupa::Models::CaseTimelineEntry.new(case: @case.id, creator: @current_user.id, date: @date).save
      @tl.encrypt(:name, @name)
      @tl.encrypt(:description, @description)
      @tl.save

      flash :success, t(:'case/timeline/create/success', id: @tl.id)
      return redirect url("/case/#{@case.id}/timeline")
    end

    haml(:'case/timeline/create', locals: {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
    })
  end

  def edit(cid, tlid)
    @entry = Kukupa::Models::CaseTimelineEntry[tlid]
    return halt 404 unless @entry
    return halt 404 unless @entry.case == @case.id

    @case_name = @case.get_name
    @title = t(:'case/timeline/edit/title', tlid: @entry.id, name: @case_name, casetype: @case.type)

    @date = @entry.date
    @name = @entry.decrypt(:name)
    @description = @entry.decrypt(:description)

    if request.post?
      @date = request.params['date']&.strip&.downcase
      @date = Chronic.parse(@date, guess: true)
      @name = request.params['name']&.strip
      @name = nil if @name&.empty?

      unless @name && @date
        flash :error, t(:'required_not_provided')
        return redirect request.path
      end

      @description = request.params['description']&.strip
      @description = Sanitize.fragment(@description, Sanitize::Config::RELAXED)
      @description = nil if @description&.strip&.empty?

      @entry.date = @date
      @entry.encrypt(:name, @name)
      @entry.encrypt(:description, @description)
      @entry.save

      flash :success, t(:'case/timeline/edit/success', id: @entry.id)
      return redirect request.path
    end

    haml(:'case/timeline/edit', locals: {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      entry: @entry,
      entry_date: @date,
      entry_name: @name,
      entry_description: @description,
    })
  end

  def delete(cid, tlid)
    return halt 404 unless has_role?("case:delete_entry")

    @entry = Kukupa::Models::CaseTimelineEntry[tlid]
    return halt 404 unless @entry
    return halt 404 unless @entry.case == @case.id

    unless request.params['confirm']&.strip&.downcase == 'on'
      flash :error, t(:'case/timeline/delete/errors/confirm_not_checked')
      return redirect url("/case/#{@case.id}/timeline/#{@entry.id}")
    end

    @entry.delete
    flash :success, t(:'case/timeline/delete/success')
    return redirect url("/case/#{@case.id}/timeline")
  end
end
