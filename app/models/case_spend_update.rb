class Kukupa::Models::CaseSpendUpdate < Sequel::Model
  def anchor
    "CaseSpendUpdate-#{self.id}"
  end
end
