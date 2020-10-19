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
end
