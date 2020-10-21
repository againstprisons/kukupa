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

  def renderables(opts = {})
    items = []

    actions =  [
      {
        url: [:url, "/case/#{self.case}/task/#{self.id}"],
        fa_icon: 'fa-gear',
      },
    ]

    items << {
      type: :task,
      id: "CaseTask[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      content: self.decrypt(:content),
      author: [:user, self.author],
      assigned_to: [:user, self.assigned_to],
      actions: actions,
    }

    items
  end

  def send_creation_email!(opts = {})
    opts[:reassigned] ||= false

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    author = Kukupa::Models::User[self.author]
    assignee = Kukupa::Models::User[self.assigned_to]
    return unless assignee

    email = Kukupa::Models::EmailQueue.new_from_template("task_new", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      task_obj: self,
      content: self.decrypt(:content),
      author: author,
      assignee: assignee,
      reassigned: opts[:reassigned],
    }).save

    email.queue_status = 'queued'
    email.encrypt(:subject, "New task assigned to you") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "list_uids",
      "uids": [assignee.id],
    }))

    email.save
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
