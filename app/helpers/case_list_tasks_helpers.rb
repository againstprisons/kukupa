module Kukupa::Helpers::CaseListTasksHelpers
  # This function always returns an array containing arrays of tasks,
  # by default the return value will only contain a single array with
  # all tasks in it, but if the :group_by_assignee option is set to true,
  # the return value will contain a list of tasks per assigned advocate.
  def case_task_list_tasks(opts = {})
    opts[:group_by_assignee] = false unless opts.key?(:group_by_assignee)

    advocates = {}
    cases = {}

    ds = Kukupa::Models::CaseTask
      .where(completion: nil)

    # get initial task details
    tasks = ds.map do |task|
      {
        id: task.id,
        case: task.case,
        anchor: task.anchor,
        content: task.decrypt(:content),
        creation: task.creation,
        author: task.author,
        assigned_to: task.assigned_to,
      }
    end

    # get case details
    tasks.map! do |task|
      unless cases.key?(task[:case].to_s)
        case_obj = Kukupa::Models::Case[task[:case]]
        cases[task[:case].to_s] = {
          id: case_obj.id,
          name: case_obj.get_name,
          url: url("/case/#{case_obj.id}/view"),
          type: case_obj.type.to_s.strip.downcase,
        }
      end

      task[:case] = cases[task[:case].to_s]
      task[:edit_url] = url("/case/#{task[:case][:id]}/task/#{task[:id]}")

      task
    end

    # get author/assignee details
    tasks.map! do |task|
      advocates = case_populate_advocate(advocates, task[:author])
      advocates = case_populate_advocate(advocates, task[:assigned_to])

      task[:author] = advocates[task[:author].to_s]
      task[:assigned_to] = advocates[task[:assigned_to].to_s] 

      task
    end

    # sort by creation
    tasks.sort! do |a, b|
      a[:creation] <=> b[:creation]
    end

    if opts[:group_by_assignee]
      out = []

      advocates.each do |_, v|
        this = tasks.filter { |t| t[:assigned_to][:id] == v[:id] }
        unless this.empty?
          out << this
        end
      end

      return out
    end

    # sort by case type
    Kukupa::Models::Case::ALLOWED_TYPES.map do |type|
      t = tasks.filter { |t| t[:case][:type] == type }
      t.empty? ? nil : t
    end.compact
  end
end
