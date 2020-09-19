class Kukupa::Models::CaseTask < Sequel::Model
  def anchor
    "CaseTask-#{self.id}"
  end
end
