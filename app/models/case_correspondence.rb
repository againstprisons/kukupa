class Kukupa::Models::CaseCorrespondence < Sequel::Model(:case_correspondence)
  def anchor
    "CaseCorrespondence-#{self.id}"
  end

  def renderables(opts = {})
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

    items << {
      type: :correspondence,
      id: "CaseCorrespondence[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      subject: self.decrypt(:subject),
      outgoing: self.sent_by_us,
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
    file = Kukupa::Models::File.where(file_id: self.file_id)
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
  
  def send_deletion_email!(user, opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj
    user = Kukupa::Models::User[user] if user.is_a?(Integer)

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
