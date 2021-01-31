require 'sanitize'

class Kukupa::Controllers::CaseCorrespondenceSendController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'
  add_route :get, '/templates', method: :templates

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::ReconnectHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user

    @prisons = Kukupa::Models::Prison.get_prisons
    @assignable_users = case_assignable_users
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @case_name = @case.get_name
    @title = t(:'case/correspondence/send/title', name: @case_name)
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    if @reconnect_data.nil?
      return haml(:'case/correspondence/send/no_reconnect', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
        reconnect_id: @reconnect_id,
        reconnect_data: @reconnect_data,
      })
    end

    @subject = @content = ''

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

      @preview = request.params['preview'].to_i.positive?

      # send the mail
      if request.params['confirm'].to_i.positive?
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

      # show a preview
      if @preview
        return haml(:'case/correspondence/send/confirm', :locals => {
          title: @title,
          case_obj: @case,
          case_name: @case_name,
          compose_subject: @subject,
          compose_content: @content,
        })
      end
    end

    return haml(:'case/correspondence/send/index', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      template_name: @template&.decrypt(:name),
      compose_subject: @subject,
      compose_content: @content,
    })
  end
  
  def templates(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @case_name = @case.get_name
    @title = t(:'case/correspondence/send/title', name: @case_name)
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    return redirect url("/case/#{@case.id}/correspondence/send") unless @reconnect_data

    @templates = Kukupa::Models::MailTemplate.template_list.reject { |tpl| !tpl[:enabled] }
    
    return haml(:'case/correspondence/send/templates', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      templates: @templates,
    })
  end
end
