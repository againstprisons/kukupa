require 'sanitize'
require 'reverse_markdown'

class Kukupa::Controllers::CaseCorrespondenceSendController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :get, '/templates', method: :templates

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::ReconnectHelpers

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @show = @case.show_desc
    return halt 404 unless @show[:correspondence]
  end

  def index(cid)
    @case_name = @case.get_name
    @title = t(:'case/correspondence/send/title', name: @case_name)

    # if email correspondence is enabled, get the `email` parameter -
    # if set, this is an email to an outside requester
    if Kukupa.app_config['feature-case-correspondence-email']
      @email = request.params['email']&.strip&.downcase
      @email = nil if @email&.empty?
    end

    # if @show[:reconnect] is false, email correspondence is enabled,
    # and we don't already have an email address to send to, show a
    # prompt for an email address before doing anything else.
    if Kukupa.app_config['feature-case-correspondence-email'] && @email.nil?
      unless @show[:reconnect]
        return haml(:'case/correspondence/send/email_prompt', :locals => {
          title: @title,
          this_url: @this_url.to_s,
          case_obj: @case,
          case_name: @case_name,
          case_show: @show,
        })
      end
    end

    # if we have no email address (or email is disabled), and @show[:reconnect]
    # is disabled, return a teapot (because users can't reach this state w/o
    # browsing to `/case/:id/correspondence/send` manually - it's hidden in
    # the user interface)
    if @email.nil? && !@show[:reconnect]
      return halt 418
    end    

    # get re:connect data, and halt if there is none EXCEPT in the case
    # that this is an email to an outside requester
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    if @email.nil? && @reconnect_data.nil?
      return haml(:'case/correspondence/send/no_reconnect', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        case_show: @show,
        reconnect_id: @reconnect_id,
        reconnect_data: @reconnect_data,
      })
    end

    @subject = ''
    @content = ''

    # construct URL to template page with email address 
    @template_url = Addressable::URI.parse(url("/case/#{@case.id}/correspondence/send/templates"))
    if @email
      @template_url.query_values = {email: @email}
    end

    # Pull in template data if we've selected a template
    if request.params['tpl'].to_i.positive?
      @template = Kukupa::Models::MailTemplate[request.params['tpl'].to_i]
      if @template && @template.enabled
        @subject = @template.decrypt(:name)
        @content = @template.decrypt(:content)
      end
    end

    @this_url = Addressable::URI.parse(url("/case/#{@case.id}/correspondence/send"))
    @this_url.query_values = @this_url_query_values = {
      tpl: @template&.id,
      email: @email,
    }

    @template_clear_url = @this_url.dup
    @template_clear_url.query_values =
      @this_url_query_values.merge({tpl: 0})

    if request.post?
      @subject = request.params['subject']&.strip || ''
      @content = request.params['content']&.strip || ''
      @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)

      @preview = request.params['preview'].to_i.positive?

      # send the mail
      if request.params['confirm'].to_i.positive?
        cm_type = 'prisoner'
        cm_type = 'email' if @email

        if @email && @case.email_identifier.nil?
          flash :error, t(:'case/correspondence/send/errors/no_email_identifier')
          @preview = true

        else
          # store content as a file
          file = Kukupa::Models::File.upload(
            @content,
            filename: "kukupa_emailcompose_#{DateTime.now.strftime('%s')}.html",
            mime_type: 'text/html',
          )

          # create unapproved correspondence entry
          cm = Kukupa::Models::CaseCorrespondence.new(
            case: @case.id,
            file_type: 'local',
            file_id: file.file_id,
            sent_by_us: true,
            approved: false,
            approved_by: nil,
            has_been_sent: false,
            correspondence_type: cm_type,
          ).save

          cm.encrypt(:subject, @subject)
          cm.encrypt(:target_email, @email) if @email
          cm.save

          if has_role?('case:correspondence:send_without_approval')
            if request.params['approve_self'].to_i.positive?
              cm.approved = true
              cm.approved_by = current_user.id
              cm.save

              result = cm.send_correspondence_to_target!
              if result == true
                flash :success, t(:'case/correspondence/send/success')
              else
                flash :success, t(:'case/correspondence/send/errors/send_failed', error: result.inspect)

                cm.approved = false
                cm.approved_by = nil
                cm.save
              end

              return redirect to "/case/#{@case.id}/view##{cm.anchor}"
            end
          end

          # TODO: send email to coordinators requesting approval
          # cm.send_approval_request_notification!

          flash :success, t(:'case/correspondence/send/success/unapproved')
          return redirect to "/case/#{@case.id}/view##{cm.anchor}"
        end
      end

      # show a preview
      if @preview
        return haml(:'case/correspondence/send/confirm', :locals => {
          title: @title,
          case_obj: @case,
          case_name: @case_name,
          case_show: @show,
          compose_subject: @subject,
          compose_content: @content,
          compose_email: @email,
        })
      end
    end

    return haml(:'case/correspondence/send/index', :locals => {
      title: @title,
      this_url: @this_url.to_s,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      template_url: @template_url.to_s,
      template_clear_url: @template_clear_url.to_s,
      template_name: @template&.decrypt(:name),
      compose_subject: @subject,
      compose_content: @content,
      compose_email: @email,
    })
  end
  
  def templates(cid)
    @case_name = @case.get_name
    @title = t(:'case/correspondence/send/title', name: @case_name)

    # is this an email to an outside requester?
    @email = request.params['email']&.strip&.downcase
    @email = nil if @email&.empty?

    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    if @email.nil? && @reconnect_data.nil?
      return redirect url("/case/#{@case.id}/correspondence/send")
    end

    @templates = Kukupa::Models::MailTemplate
      .template_list(@case, email: @email)
      .reject { |tpl| !tpl[:enabled] }

    @grouped_templates = Kukupa.app_config['case-mail-template-groups'].map{|x| [x, []]}.to_h
    @templates.each do |tpl|
      if @grouped_templates.key?(tpl[:group])
        @grouped_templates[tpl[:group]] << tpl
      else
        @grouped_templates[t(:'unknown')] = []
        @grouped_templates[t(:'unknown')] << tpl
      end
    end
    
    return haml(:'case/correspondence/send/templates', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      templates: @templates,
      grouped_templates: @grouped_templates,
      compose_email: @email,
    })
  end
end
