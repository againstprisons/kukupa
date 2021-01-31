class Kukupa::Models::CaseSpend < Sequel::Model
  def anchor
    "CaseSpend-#{self.id}"
  end

  def get_year
    self.creation.strftime("%Y")
  end

  def renderables(opts = {})
    items = []

    actions =  [
      {
        url: [:url, "/case/#{self.case}/spend/#{self.id}"],
        fa_icon: 'fa-gear',
      },
    ]

    if self.approver.nil? && opts[:spend_can_approve]
      actions.insert(0, {
        url: [:url, "/case/#{self.case}/spend/#{self.id}/approve"],
        fa_icon: 'fa-check-square-o',
      })
    end

    edited_ts = Kukupa::Models::CaseSpendUpdate
      .select(:id, :spend, :creation)
      .where(spend: self.id)
      .reverse(:creation)
      .map(&:creation)
      .first

    items << {
      type: :spend,
      id: "CaseSpend[#{self.id}]",
      anchor: self.anchor,
      case_spend: self,
      creation: self.creation,
      amount: self.decrypt(:amount).to_f,
      notes: self.decrypt(:notes),
      edited: edited_ts,
      author: [:user, self.author],
      approver: [:user, self.approver],
      actions: actions,
    }

    unless self.approved.nil?
      approve_actions = [
        {
          url: "##{self.anchor}",
          fa_icon: 'fa-external-link',
        }
      ]

      items << {
        type: :spend_approve,
        id: "CaseSpend[#{self.id}]",
        anchor: "Approve-#{self.anchor}",
        creation: self.approved,
        amount: self.decrypt(:amount),
        author: [:user, self.approver],
        actions: approve_actions,
      }
    end

    items
  end

  def send_creation_email!(opts = {})
    opts[:autoapproved] ||= false
    opts[:edited] ||= false

    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj
    author = Kukupa::Models::User[self.author]
    return unless author

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    subject_meta = [
      opts[:autoapproved] ? 'auto-approved' : nil,
    ].compact

    subject = "Case spend #{opts[:edited] ? 'edited' : 'added'}" # TODO: tl this
    subject = "#{subject} (#{subject_meta.join(', ')})" unless subject_meta.empty?

    email = Kukupa::Models::EmailQueue.new_from_template("spend_new", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      spend_obj: self,
      content: self.decrypt(:notes),
      amount: self.decrypt(:amount).to_f,
      author: author,
      autoapproved: opts[:autoapproved],
      edited: opts[:edited],
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, subject)
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def send_approve_email!(opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    approver = Kukupa::Models::User[self.approver]
    author = Kukupa::Models::User[self.author]

    to_email = [
      author&.id,
      approver&.id,
      case_obj.get_assigned_advocates,
    ].flatten.compact.uniq
    return if to_email.empty?

    email = Kukupa::Models::EmailQueue.new_from_template("spend_approved", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      spend_obj: self,
      content: self.decrypt(:notes),
      amount: self.decrypt(:amount).to_f,
      author: author,
      approver: approver,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "Spend approved") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "list_uids",
      "uids": to_email,
    }))

    email.save
  end

  def send_deletion_email!(user, opts = {})
    case_obj = Kukupa::Models::Case[self.case]
    return unless case_obj
    user = Kukupa::Models::User[user] if user.is_a?(Integer)

    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{case_obj.id}/view"

    email = Kukupa::Models::EmailQueue.new_from_template("spend_delete", {
      case_obj: case_obj,
      case_url: case_url.to_s,
      spend_obj: self,
      content: self.decrypt(:notes),
      amount: self.decrypt(:amount).to_f,
      user: user,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "Case spend deleted") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def delete!
    Kukupa::Models::CaseSpendUpdate
      .where(spend: self.id)
      .map(&:delete)

    self.delete
  end
end
