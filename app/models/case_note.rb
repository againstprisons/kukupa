class Kukupa::Models::CaseNote < Sequel::Model
  def anchor
    "CaseNote-#{self.id}"
  end

  def outside_request_email!(opts = {})
    return unless self.is_outside_request

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    request_metadata = JSON.parse(self.decrypt(:metadata))
    case_is_new = opts[:case_is_new] || false

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    # email to admins
    begin
      admin_email = Kukupa::Models::EmailQueue.new_from_template("outside_request", {
        case_obj: case_obj,
        case_url: case_url.to_s,
        case_is_new: case_is_new,
      })

      admin_email.queue_status = 'queued'
      admin_email.encrypt(:subject, "New outside request") # TODO: tl this
      admin_email.encrypt(:recipients, JSON.generate({
        "mode": "roles",
        "roles": ["case:alerts"],
      }))

      admin_email.save
    end

    # email to assigned advocate
    unless case_obj.assigned_advocate.nil?
      advocate_email = Kukupa::Models::EmailQueue.new_from_template("outside_request", {
        case_obj: case_obj,
        case_url: case_url.to_s,
        case_is_new: case_is_new,
      })

      advocate_email.queue_status = 'queued'
      advocate_email.encrypt(:subject, "New outside request") # TODO: tl this
      advocate_email.encrypt(:recipients, JSON.generate({
        "mode": "list_uids",
        "uids": [case_obj.assigned_advocate],
      }))

      advocate_email.save
    end

    # confirmation email to requester
    unless request_metadata['email'].nil? || request_metadata['email']&.empty?
      confirm_email = Kukupa::Models::EmailQueue.new_from_template("outside_request_confirm", {
        case_obj: case_obj,
      })

      confirm_email.queue_status = 'queued'
      confirm_email.encrypt(:subject, "Your advocacy request was received") # TODO: tl this
      confirm_email.encrypt(:recipients, JSON.generate({
        "mode": "list",
        "list": [request_metadata['email']],
      }))

      confirm_email.save
    end
  end

  def send_creation_email!(opts = {})
    opts[:edited] ||= false

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj
    return unless case_obj.assigned_advocate&.positive?

    author = Kukupa::Models::User[self.author]
    return unless author

    note_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    note_url += "/case/#{case_obj.id}/view##{self.anchor}"

    subject = "Case note #{opts[:edited] ? 'edited' : 'added'}" # TODO: tl this

    email = Kukupa::Models::EmailQueue.new_from_template("note_new", {
      case_obj: case_obj,
      note_url: note_url.to_s,
      spend_obj: self,
      author: author,
      edited: opts[:edited],
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, subject)
    email.encrypt(:recipients, JSON.generate({
      "mode": "list_uids",
      "uids": [case_obj.assigned_advocate],
    }))

    email.save
  end

  def send_deletion_email!(user, opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj
    user = Kukupa::Models::User[user] if user.is_a?(Integer)
    author = Kukupa::Models::User[self.author]

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    email = Kukupa::Models::EmailQueue.new_from_template("note_delete", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      spend_obj: self,
      content: self.decrypt(:content),
      author: author,
      user: user,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "Case note deleted") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def delete!
    Kukupa::Models::CaseNoteUpdate
      .where(note: self.id)
      .map(&:delete)

    self.delete
  end
end
