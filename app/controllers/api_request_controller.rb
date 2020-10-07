class Kukupa::Controllers::ApiRequestController < Kukupa::Controllers::ApiController
  add_route :post, '/'

  def index
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

    # bail if we're missing any info
    if errs.any?
      return halt 400, api_json({
        success: false,
        error: 'Missing required information',
      })
    end

    # try and find a case with the given PRN
    @case_id = Kukupa::Models::CaseFilter
      .perform_filter(:prisoner_number, @prn)
      .first
      &.case

    @case = Kukupa::Models::Case[@case_id] if @case_id

    # if we can't find a case, create a new one
    unless @case
      @case_is_new = true

      # create new case with provided information
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

    # send alert email
    begin
      case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      case_url += "/case/#{@case.id}/view"

      @admin_email = Kukupa::Models::EmailQueue.new_from_template("outside_request", {
        case_obj: @case,
        case_url: case_url.to_s,
        case_is_new: @case_is_new,
      })

      @admin_email.queue_status = 'queued'
      @admin_email.encrypt(:subject, "New outside request") # TODO: tl this
      @admin_email.encrypt(:recipients, JSON.generate({
        "mode": "roles",
        "roles": ["case:alerts"],
      }))

      @admin_email.save

      unless @case.assigned_advocate.nil?
        @advocate_email = Kukupa::Models::EmailQueue.new_from_template("outside_request", {
          case_obj: @case,
          case_url: case_url.to_s,
          case_is_new: @case_is_new,
        })

        @advocate_email.queue_status = 'queued'
        @advocate_email.encrypt(:subject, "New outside request") # TODO: tl this
        @advocate_email.encrypt(:recipients, JSON.generate({
          "mode": "list_uids",
          "uids": [@case.assigned_advocate],
        }))

        @advocate_email.save
      end
    end

    return api_json({
      success: true,
    })
  end
end
