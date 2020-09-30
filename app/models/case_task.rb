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

    update = Kukupa::Models::CaseTaskUpdate
      .where(task: self.id)
      .order(Sequel.desc(:creation))
      .first
    dates << update.creation if update

    dates.compact.sort.last
  end
end
