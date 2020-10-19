class Kukupa::Models::CaseTask < Sequel::Model
  def anchor
    "CaseTask-#{self.id}"
  end

  def last_updated
    dates = [
      self.creation,
      self.completion,
      self.reminded,
    ]

    dates << Kukupa::Models::CaseTaskUpdate
      .where(task: self.id)
      .reverse(:creation)
      .first
      &.creation

    dates.compact.sort.last
  end

  def send_deletion_email!(user, opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    user = Kukupa::Models::User[user] if user.is_a?(Integer)
    author = Kukupa::Models::User[self.author]
    assignee = Kukupa::Models::User[self.assigned_to]

    email = Kukupa::Models::EmailQueue.new_from_template("task_delete", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      task_obj: self,
      content: self.decrypt(:content),
      author: author,
      assignee: assignee,
      user: user,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "Case task deleted") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def delete!
    Kukupa::Models::CaseTaskUpdate
      .where(task: self.id)
      .map(&:delete)

    self.delete
  end
end
