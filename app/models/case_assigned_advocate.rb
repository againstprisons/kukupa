class Kukupa::Models::CaseAssignedAdvocate < Sequel::Model
  def send_new_assignee_email!(opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"
    
    email = Kukupa::Models::EmailQueue.new_from_template("case_new_assignee", {
      case_obj: case_obj,
      case_url: case_url.to_s,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "You have been assigned to a new case") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "list_uids",
      "uids": [self.user],
    }))

    email.save
  end

  def delete!
    self.delete
  end
end
