class Kukupa::Models::CaseNoteUpdate < Sequel::Model
  def anchor
    "CaseNoteUpdate-#{self.id}"
  end
end
