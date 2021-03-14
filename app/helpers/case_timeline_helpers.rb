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

  def timeline_entry_for_task(task)
    assignee = Kukupa::Models::User[task.assigned_to]

    {
      is_task: true,
      obj: task,
      id: task.id,
      date: task.deadline,
      in_past: task.deadline < Time.now,
      name: task.decrypt(:content),
      description: nil,
      creator: assignee,
      creation: task.creation,
      anchor: task.anchor,
    }
  end

  def timeline_entries_for_case(case_)
    cid = case_
    cid = case_.id if case_.respond_to?(:id)
    entries = []

    # actual timeline entries
    entries << Kukupa::Models::CaseTimelineEntry.where(case: cid).map do |tl|
      timeline_entry(tl)
    end

    # incomplete case tasks
    entries << Kukupa::Models::CaseTask.where(case: cid, completion: nil).map do |ct|
      timeline_entry_for_task(ct)
    end

    entries.flatten!
    entries.sort! {|a, b| a[:date] <=> b[:date]}
    entries
  end
end
