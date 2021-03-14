class Kukupa::Models::CaseTimelineEntry < Sequel::Model(:case_timeline_entries)
  def anchor
    "CaseTimelineEntry-#{self.id}"
  end
end
