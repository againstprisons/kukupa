class Kukupa::Models::CaseTaskUpdate < Sequel::Model
  def anchor
    "CaseTaskUpdate-#{self.id}"
  end
end
