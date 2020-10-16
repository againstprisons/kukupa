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
  end
end
