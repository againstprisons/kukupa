class Kukupa::Models::CaseCorrespondence < Sequel::Model(:case_correspondence)
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

    if !self.sent_by_us && self.correspondence_type == 'email' && target_email
      reply_url = Addressable::URI.parse("/case/#{self.case}/correspondence/send")
      reply_url.query_values = {email: target_email}

      actions.unshift({
        url: [:url, reply_url],
        fa_icon: 'fa-mail-reply',
      })
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
