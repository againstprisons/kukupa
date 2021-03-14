require 'chronic'

module Kukupa::Helpers::CaseTimelineHelpers
  def timeline_entry(tl)
    creator = Kukupa::Models::User[tl.creator]
    description = tl.decrypt(:description)
    description = nil if description&.strip&.empty?

    {
      obj: tl,
      id: tl.id,
      date: tl.date,
      in_past: tl.date < Time.now,
      name: tl.decrypt(:name),
      description: description,
      creator: creator,
      creation: tl.creation,
      anchor: tl.anchor,
    }
  end

  def timeline_entries_for_case(case_)
    cid = case_
    cid = case_.id if case_.respond_to?(:id)

    entries = Kukupa::Models::CaseTimelineEntry.where(case: cid).map do |tl|
      timeline_entry(tl)
    end

    entries.sort! {|a, b| a[:date] <=> b[:date]}
    entries
  end
end
