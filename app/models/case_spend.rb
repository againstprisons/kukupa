class Kukupa::Models::CaseSpend < Sequel::Model
  def anchor
    "CaseSpend-#{self.id}"
  end

  def get_year
    self.creation.strftime("%Y")
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
