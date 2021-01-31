class Kukupa::Controllers::OutsideRequestController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    @title = t(:'outside/request/title')

    if request.post?
      @content = request.params['content']&.strip
      @content = nil if @content&.empty?
      @content = Sanitize.fragment(@content, Sanitize::Config::BASIC) if @content

      @requester_name = request.params['requester_name']&.strip
      @requester_name = nil if @requester_name&.empty?
      @requester_email = request.params['requester_email']&.strip&.downcase
      @requester_email = nil if @requester_email&.empty?
      @requester_phone = request.params['requester_phone']&.strip&.downcase
      @requester_phone = nil if @requester_phone&.empty?

      @name_first = request.params['name_first']&.strip
      @name_first = nil if @name_first&.empty?
      @name_last = request.params['name_last']&.strip
      @name_last = nil if @name_last&.empty?
      @prison = request.params['prison']&.strip
      @prison = nil if @prison&.empty?
      @prn = request.params['prn']&.strip&.downcase
      @prn = nil if @prn&.empty?

      errs = [
        @content.nil?,
        @requester_name.nil?,
        @requester_phone.nil? && @requester_email.nil?,
        @name_first.nil?,
        @name_last.nil?,
        @prison.nil?,
        @prn.nil?,
      ]

      if errs.none?
        # try and find a case with the given PRN
        @case_id = Kukupa::Models::CaseFilter
          .perform_filter(:prisoner_number, @prn)
          .first
          &.case

        @case = Kukupa::Models::Case[@case_id] if @case_id

        # if case doesn't exist, create a new case
        unless @case
          @case_is_new = true

          @case = Kukupa::Models::Case.new(is_open: true).save
          @case.encrypt(:first_name, @name_first)
          @case.encrypt(:last_name, @name_last)
          @case.encrypt(:prisoner_number, @prn)
          @case.save

          Kukupa::Models::CaseFilter.create_filters_for(@case)

          # Add "system" case note with the prison
          @sysnote = Kukupa::Models::CaseNote.new(case: @case.id).save
          @sysnote.encrypt(:content, t(
            :'outside/request/system_case_note_creation',
            force_language: true,
            prison: @prison,
            now: @sysnote.creation
          ))
          @sysnote.save
        end

        # create request metadata object
        @metadata = {
          name: @requester_name,
          email: @requester_email,
          phone: @requester_phone,
          prison: @prison,
        }

        # create an outside request in the given case
        @request = Kukupa::Models::CaseNote.new(
          case: @case.id,
          author: nil,
          is_outside_request: true,
        ).save
        @request.encrypt(:metadata, JSON.generate(@metadata))
        @request.encrypt(:content, @content)
        @request.save

        @request.outside_request_email!(case_is_new: @case_is_new)

        return haml :'outside/request/complete', :locals => {
          title: t(:'outside/request/complete/title'),
        }

      else
        flash :error, t(:'outside/request/errors/missing_required')
      end
    end

    haml :'outside/request/index', :locals => {
      title: @title,
      requester_name: @requester_name,
      requester_phone: @requester_phone,
      requester_email: @requester_email,
      name_first: @name_first,
      name_last: @name_last,
      prison: @prison,
      prn: @prn,
      content: @content,
    }
  end
end
