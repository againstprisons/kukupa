class Kukupa::Models::CaseNote < Sequel::Model
  def anchor
    "CaseNote-#{self.id}"
  end
end
