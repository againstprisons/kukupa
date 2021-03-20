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

    @show = Kukupa::Models::Case::CASE_TYPES[@case.type.to_sym][:show]
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

    @subject = @content = ''

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

    if request.post?
      @subject = request.params['subject']&.strip || ''
      @content = request.params['content']&.strip || ''
      @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)
      @content_text = ReverseMarkdown.convert(@content)

      @preview = request.params['preview'].to_i.positive?

      # send the mail
      if request.params['confirm'].to_i.positive?
        # is this an outside request email?
        if @email

          # if we have an email identifier, continue sending
          if @case.email_identifier
            # store email content as a file
            file = Kukupa::Models::File.upload(
              @content,
              filename: "kukupa_emailcompose_#{DateTime.now.strftime('%s')}.html",
              mime_type: 'text/html',
            )

            # create correspondence entry
            cm = Kukupa::Models::CaseCorrespondence.new(
              case: @case.id,
              file_type: 'local',
              file_id: file.file_id,
              sent_by_us: true,
              correspondence_type: 'email',
            ).save

            cm.encrypt(:target_email, @email)
            cm.encrypt(:subject, @subject)
            cm.save

            # create email queue entry
            eq = Kukupa::Models::EmailQueue.new_from_template(nil, {
              # layout
              layout: {
                html: "reply_layout.html.erb",
                text: "reply_layout.txt.erb",
              },

              # content
              content_text: @content_text,
              content_html: @content,

              # template data
              email_identifier: @case.email_identifier,
            })

            eq.queue_status = 'queued'
            eq.encrypt(:subject, @subject)
            eq.encrypt(:recipients, JSON.generate({
              mode: 'list',
              list: [@email],
            }))
            eq.encrypt(:message_opts, JSON.generate({
              no_autogen_headers: true,
              reply_to: Kukupa.app_config['email-outgoing-reply-to'].gsub('%IDENTIFIER%', @case.email_identifier),
            }))

            eq.save

            flash :success, t(:'case/correspondence/send/success/email')
            return redirect to "/case/#{@case.id}/view##{cm.anchor}"

          # else, no email identifier
          else 
            flash :error, t(:'case/correspondence/send/errors/no_email_identifier')
            @preview = true
          end

        # else, this is a re:connect mail send
        else
          begin
            data = reconnect_send_mail(@reconnect_id, @content)

            case_id = @case.id
            cm = Kukupa::Models::CaseCorrespondence.find_or_create(reconnect_id: data['id'].to_i) do |cm|
              cm.case = case_id
              cm.creation = Chronic.parse(data['creation'])
              cm.file_type = 'reconnect'
              cm.file_id = data['file_id']
              cm.sent_by_us = (data['sending_penpal']['id'].to_s == Kukupa.app_config['reconnect-penpal-id'].to_s)
            end.save

            cm.encrypt(:subject, @subject)
            cm.save

            flash :success, t(:'case/correspondence/send/success')
            return redirect to "/case/#{@case.id}/view##{cm.anchor}"

          rescue => e
            error_id = Kukupa::Crypto.generate_token_short
            $stderr.puts "----- Error ID #{error_id} -----"
            $stderr.puts e.inspect
            $stderr.puts e.backtrace
            $stderr.flush

            flash :error, t(:'case/correspondence/send/errors/reconnect_err', error_id: error_id)
            @preview = true
          end
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
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      template_url: @template_url.to_s,
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
    
    return haml(:'case/correspondence/send/templates', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_show: @show,
      templates: @templates,
      compose_email: @email,
    })
  end
end
