require 'mail'
require 'kramdown'

class Kukupa::Models::CaseCorrespondence < Sequel::Model(:case_correspondence)
  class ReconnectHelpers
    extend Kukupa::Helpers::ReconnectHelpers
  end

  def self.new_from_incoming_email(message)
    return nil unless message.is_a?(Mail::Message)
    creation = DateTime.now

    # check if we have a CaseCorrespondence entry with this message's
    # Message-Id header, and if we do, just return that
    existing = self.where(email_messageid: message.message_id).first
    return existing if existing

    # create a regexp from the configured email-outgoing-reply-to value,
    # substituting the identifier marker with a capture group
    to_address_re = Regexp.new Kukupa.app_config['email-outgoing-reply-to']
      .gsub(/\+/, '\\\\+')
      .gsub(/\./, '\\\\.')
      .gsub('%IDENTIFIER%', '(\w+)')

    # try to match the message To address against the reply-to pattern,
    # returning early if there's no match
    tm = nil
    [message.to, message.cc].flatten.compact.each do |to|
      tm = to_address_re.match(to)
      break if tm
    end
    return :no_re_match unless tm

    # find the case with the email identifier from the To address,
    # returning early if we can't find one
    case_obj = Kukupa::Models::Case.where(email_identifier: tm[1]).first
    return :no_case_obj unless case_obj

    # okay, we have a case! let's get the message content.
    message_html = message.html_part&.body&.to_s
    message_html = nil if message_html&.empty?
    unless message_html
      message_text = message.text_part&.body&.to_s
      message_text = nil if message_text&.empty?

      if message_text
        message_html = Kramdown::Document.new(message_text).to_html
      else
        message_html = '<p><strong>WARNING:</strong> This incoming email did not contain a readable body.</p>'
      end
    end

    # force encode message body to the transport encoding
    if (ct = /charset=([a-zA-Z0-9_-]+)/.match((message.html_part || message.text_part)&.content_type)&.[](1))
      message_html.force_encoding(ct)
    end

    # re-encode message body to UTF-8
    message_html = message_html.encode(
      Encoding::UTF_8,
      invalid: :replace,
      undef: :replace,
      replace: "\uFFFD",
    )

    # we've got the message html, let's check for our banner
    our_banner = "[[[ Please keep your reply above this line | #{case_obj.email_identifier} ]]]"
    banner_idx = message_html.index(our_banner)

    # if we found our banner, grab everything before it. if we didn't find
    # our banner, just use the whole message text (just as a safety measure)
    if banner_idx
      message_html = message_html[0..(banner_idx - 1)]
    end

    # do a sanitize pass on the resulting html, which will strip out all of
    # the stuff we don't want to store, including the HTML before the banner
    # in our original email. this is the easiest way to get rid of all that!
    message_html = Sanitize.fragment(message_html, Sanitize::Config::BASIC)

    # prepend a doctype and a meta charset tag to the message html so it
    # renders properly in the FileDownloadController view mode
    message_html = "<!DOCTYPE html>\n<head><meta charset=\"utf-8\"></head>\n#{message_html}"

    # store the message HTML as a local file
    filename = "incomingemail-#{creation.strftime('%s')}-case#{case_obj.id}.html"
    file_obj = Kukupa::Models::File.upload(message_html, filename: filename)

    # and store the original message as a local file
    eml_filename = "incomingemail-#{creation.strftime('%s')}-case#{case_obj.id}.eml"
    eml_file_obj = Kukupa::Models::File.upload(message.to_s, filename: eml_filename)

    # okay, let's create a CaseCorrespondence entry!
    ccobj = self.new(case: case_obj.id, sent_by_us: false, correspondence_type: 'email', creation: creation).save
    ccobj.email_messageid = message.message_id
    ccobj.email_original_fileid = eml_file_obj.file_id
    ccobj.file_type = 'local'
    ccobj.file_id = file_obj.file_id
    ccobj.encrypt(:target_email, message.from.first)
    ccobj.encrypt(:subject, message.subject)
    ccobj.save

    # we're done here! return the CaseCorrespondence entry
    ccobj
  end

  def anchor
    "CaseCorrespondence-#{self.id}"
  end

  def renderables(opts = {})
    target_email = self.decrypt(:target_email)
    target_email = nil if target_email&.empty?

    items = []
    actions = [
      {
        url: [:url, "/case/#{self.case}/correspondence/#{self.id}/dl"],
        fa_icon: (self.file_type == 'local' && self.sent_by_us) ? 'fa-eye' : 'fa-download',
      },
      {
        url: [:url, "/case/#{self.case}/correspondence/#{self.id}"],
        fa_icon: 'fa-gear',
      },
    ]

    # if email correspondence is enabled, this correspondence is of
    # type `email`, this correspondence was not sent by us, and the
    # `target_email` field is not `nil`, show a reply button
    if Kukupa.app_config['feature-case-correspondence-email']
      if self.correspondence_type == 'email' && !self.sent_by_us && target_email
        reply_url = Addressable::URI.parse("/case/#{self.case}/correspondence/send")
        reply_url.query_values = {email: target_email}

        actions.unshift({
          url: [:url, reply_url],
          fa_icon: 'fa-mail-reply',
        })
      end
    end

    approval = false
    if self.approved
      approval = [:user, self.approved_by]
    end

    items << {
      type: :correspondence,
      id: "CaseCorrespondence[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      subject: self.decrypt(:subject),
      outgoing: self.sent_by_us,
      correspondence_type: self.correspondence_type,
      target_email: target_email,
      approval: approval,
      actions: actions,
    }

    items
  end

  def get_download_url(opts = {})
    meth = "get_download_url__#{self.file_type}".to_sym
    return self.send(meth, opts) if self.respond_to?(meth)
    nil
  end
  
  def get_download_url__local(opts = {})
    file = Kukupa::Models::File.where(file_id: self.file_id).first
    return nil unless file
    
    token = file.generate_download_token(opts[:user])

    url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    url += "/filedl/#{file.file_id}/#{token.token}"
    url.to_s
  end

  def get_download_url__reconnect(opts = {})
    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/dltoken'

    req_opts = {
      method: :post,
      body: {
        fileid: self.file_id,
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    return nil unless response.success?

    begin
      data = JSON.parse(response.body)
    rescue => e
      return nil
    end

    return nil unless data['success']
    data['url']
  end

  def get_file_content(opts = {})
    meth = "get_file_content__#{self.file_type}".to_sym
    return self.send(meth, opts) if self.respond_to?(meth)
    nil
  end
  
  def get_file_content__local(opts = {})
    file = Kukupa::Models::File.where(file_id: self.file_id).first
    return nil unless file
    file.decrypt_file
  end

  def get_file_content__reconnect(opts = {})
    url = self.get_download_url__reconnect
    return nil unless url

    out = Typhoeus.get(url)
    return nil unless out.response_code == 200
    out.body
  end

  def send_correspondence_to_target!(opts = {})
    return unless self.sent_by_us # just for outgoing mail
    return unless self.approved # only send approved mail
    unless opts[:send_again]
      # return if we've already sent this correspondence, unless we have
      # a "send again" override flag
      return if self.has_been_sent 
    end

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    meth = "send_correspondence_to_target__#{self.correspondence_type}".to_sym
    return send(meth, case_obj, opts) if respond_to?(meth)
    :unknown_type
  end

  def send_correspondence_to_target__email(case_obj, opts = {})
    target_email = self.decrypt(:target_email)
    target_email = nil if target_email&.empty?
    return :email_no_target unless target_email

    content = self.get_file_content
    content = '' if content&.empty?
    content_text = ReverseMarkdown.convert(content)

    eq = Kukupa::Models::EmailQueue.new_from_template(nil, {
      # layout
      layout: {
        html: "reply_layout.html.erb",
        text: "reply_layout.txt.erb",
      },

      # content
      content_text: content_text,
      content_html: content,

      # template data
      email_identifier: case_obj.email_identifier,
    })

    eq.queue_status = 'queued'
    eq.encrypt(:subject, self.decrypt(:subject))
    eq.encrypt(:recipients, JSON.generate({mode: 'list', list: [target_email]}))
    eq.encrypt(:message_opts, JSON.generate({
      no_autogen_headers: true,
      reply_to: Kukupa.app_config['email-outgoing-reply-to'].gsub('%IDENTIFIER%', case_obj.email_identifier),
    }))

    eq.save

    self.has_been_sent = true
    self.save

    true
  end

  def send_correspondence_to_target__prisoner(case_obj, opts = {})
    content = self.get_file_content
    content = nil if content&.empty?
    return :correspondence_no_content unless content

    reconnect_id = case_obj.reconnect_id
    return :prisoner_no_reconnect_id unless reconnect_id

    begin
      result = ReconnectHelpers.reconnect_send_mail(reconnect_id, content)
    rescue => e
      error_id = Kukupa::Crypto.generate_token_short
      $stderr.puts "----- Error ID #{error_id} -----"
      $stderr.puts e.inspect
      $stderr.puts e.backtrace
      $stderr.flush

      return "reconnect_exception__#{error_id}".to_sym
    end
    
    unless result['success']
      return "reconnect_no_success__#{result['message']&.tr(' ', '_')&.downcase}".to_sym
    end

    reconnect_id = result['id'].to_i
    return :reconnect_id_zero if reconnect_id.zero?

    self.reconnect_id = reconnect_id
    self.has_been_sent = true
    self.save

    true
  end

  def create_outgoing_print_task!
    return unless self.approved
    if Kukupa.app_config['correspondence-print-only-prisoner']
      return unless self.correspondence_type == 'prisoner'
    end

    language = Kukupa::Helpers::LanguageHelpers::LanguageData.new
    assignee = Kukupa.app_config['correspondence-print-users'].sample

    task = Kukupa::Models::CaseTask.new({
      case: self.case,
      author: nil,
      assigned_to: assignee,
      deadline: Chronic.parse(Kukupa.app_config['task-default-deadline']),
    }).save

    task.encrypt(:content, language.t(:'case/correspondence/send/automatic_task', {
      cid: self.id,
      url: Kukupa.app_config['base-url'] + "/case/#{self.case}/correspondence/#{self.id}/dl/view",
      force_language: true,
    }))

    task.save
  end

  def send_incoming_alert_email!(opts = {})
    return if self.sent_by_us # this is just for incoming mail

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    email = Kukupa::Models::EmailQueue.new_from_template("correspondence_new_incoming", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      cc_obj: self,
      cc_subject: self.decrypt(:subject),
    })

    send_to_uids = case_obj.get_assigned_advocates.compact.uniq
    recipients = {"mode": "list_uids", "uids": send_to_uids}
    subject = "New correspondence for a case you're assigned to" # TODO: tl this
    if send_to_uids.empty?
      recipients = {"mode": "roles", "roles": ["case:alerts"]}
      subject = "New correspondence for a case with no assignees" # TODO: tl this
    end

    email.queue_status = 'queued'
    email.encrypt(:subject, subject)
    email.encrypt(:recipients, JSON.generate(recipients))
    email.save
  end
  
  def send_deletion_email!(user, opts = {})
    user = Kukupa::Models::User[user] if user.is_a?(Integer)

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    email = Kukupa::Models::EmailQueue.new_from_template("correspondence_delete", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      cc_obj: self,
      cc_subject: self.decrypt(:subject),
      user: user,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "Case correspondence deleted") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def delete!
    self.delete
  end
end
