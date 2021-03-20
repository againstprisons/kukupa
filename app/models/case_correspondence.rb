require 'mail'
require 'kramdown'

class Kukupa::Models::CaseCorrespondence < Sequel::Model(:case_correspondence)
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
    message.to.each do |to|
      tm = to_address_re.match(to)
      break if tm
    end
    return nil unless tm

    # find the case with the email identifier from the To address,
    # returning early if we can't find one
    case_obj = Kukupa::Models::Case.where(email_identifier: tm[1]).first
    return nil unless case_obj

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

    # okay, let's create a CaseCorrespondence entry!
    ccobj = self.new(case: case_obj.id, sent_by_us: false, correspondence_type: 'email', creation: creation).save
    ccobj.email_messageid = message.message_id
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
        fa_icon: 'fa-download',
      },
      {
        url: [:url, "/case/#{self.case}/correspondence/#{self.id}"],
        fa_icon: 'fa-gear',
      },
    ]

    if self.sent_by_us
      actions.unshift({
        url: [:url, "/case/#{self.case}/correspondence/#{self.id}/dl/print"],
        fa_icon: 'fa-print',
        target: '_blank',
      })
    end

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

    items << {
      type: :correspondence,
      id: "CaseCorrespondence[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      subject: self.decrypt(:subject),
      outgoing: self.sent_by_us,
      correspondence_type: self.correspondence_type,
      target_email: target_email,
      actions: actions,
    }

    items
  end

  def get_download_url(opts = {})
    meth = "get_download_url_#{self.file_type}".to_sym
    return self.send(meth, opts) if self.respond_to?(meth)
    nil
  end
  
  def get_download_url_local(opts = {})
    file = Kukupa::Models::File.where(file_id: self.file_id).first
    return nil unless file
    
    token = file.generate_download_token(opts[:user])

    url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    url += "/filedl/#{file.file_id}/#{token.token}"
    url.to_s
  end

  def get_download_url_reconnect(opts = {})
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
    meth = "get_file_content_#{self.file_type}".to_sym
    return self.send(meth, opts) if self.respond_to?(meth)
    nil
  end
  
  def get_file_content_local(opts = {})
    file = Kukupa::Models::File.where(file_id: self.file_id).first
    return nil unless file
    file.decrypt_file
  end

  def get_file_content_reconnect(opts = {})
    url = self.get_download_url_reconnect
    return nil unless url

    out = Typhoeus.get(url)
    return nil unless out.response_code == 200
    out.body
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
