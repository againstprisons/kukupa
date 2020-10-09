module Kukupa::Helpers::CaseViewHelpers
  def get_tasks(c, opts = {})
    c = c.id if c.respond_to?(:id)
    advocates = {}

    ds = Kukupa::Models::CaseTask.where(case: c)
    ds = ds.where(completion: nil) unless opts[:include_complete]

    tasks = ds.map do |ct|
      advocates = case_populate_advocate(advocates, ct.author)
      advocates = case_populate_advocate(advocates, ct.assigned_to)

      {
        id: "CaseTask[#{ct.id}]",
        url: url("/case/#{c}/task/#{ct.id}"),
        anchor: ct.anchor,
        creation: ct.creation,
        completion: ct.completion,
        content: ct.decrypt(:content),
        author: advocates[ct.author.to_s],
        assigned_to: advocates[ct.assigned_to.to_s],
      }
    end

    complete = tasks.select { |x| x[:completion] != nil }
    tasks.reject! { |x| x[:completion] != nil }
    tasks.sort! { |a, b| b[:creation] <=> a[:creation] }
    complete.sort! { |a, b| b[:completion] <=> a[:completion] }

    [tasks, complete].flatten
  end

  def get_renderables(c)
    c = c.id if c.respond_to?(:id)

    cuser = current_user
    advocates = {}

    items = []

    Kukupa::Models::CaseNote.where(case: c).each do |cn|
      actions =  [
        {
          url: url("/case/#{c}/note/#{cn.id}"),
          fa_icon: 'fa-gear',
        },
      ]

      begin
        metadata = JSON.parse(cn.decrypt(:metadata) || '{}')
        metadata = metadata.keys.map do |k|
          [k.to_sym, metadata[k]]
        end.to_h
      rescue
        metadata = {}
      end

      advocates = case_populate_advocate(advocates, cn.author)

      items << {
        type: :case_note,
        id: "CaseNote[#{cn.id}]",
        anchor: cn.anchor,
        case_note: cn,
        creation: cn.creation,
        edited: cn.edited,
        content: cn.decrypt(:content),
        outside_request: cn.is_outside_request,
        metadata: metadata,
        author: advocates[cn.author.to_s],
        actions: actions,
      }
    end

    Kukupa::Models::CaseSpend.where(case: c).each do |cs|
      actions =  [
        {
          url: url("/case/#{c}/spend/#{cs.id}"),
          fa_icon: 'fa-gear',
        },
      ]

      if cs.approver.nil? && has_role?('case:spend:can_approve')
        actions.insert(0, {
          url: url("/case/#{c}/spend/#{cs.id}/approve"),
          fa_icon: 'fa-check-square-o',
        })
      end

      advocates = case_populate_advocate(advocates, cs.author)
      advocates = case_populate_advocate(advocates, cs.approver)

      unless cs.approved.nil?
        approve_actions = [
          {
            url: "##{cs.anchor}",
            fa_icon: 'fa-external-link',
          }
        ]

        items << {
          type: :spend_approve,
          id: "CaseSpend[#{cs.id}]",
          anchor: "Approve-#{cs.anchor}",
          case_spend: cs,
          creation: cs.approved,
          amount: cs.decrypt(:amount),
          author: advocates[cs.approver.to_s],
          actions: approve_actions,
        }
      end

      items << {
        type: :spend,
        id: "CaseSpend[#{cs.id}]",
        anchor: cs.anchor,
        case_spend: cs,
        creation: cs.creation,
        amount: cs.decrypt(:amount),
        notes: cs.decrypt(:notes),
        author: advocates[cs.author.to_s],
        approver: advocates[cs.approver.to_s],
        actions: actions,
      }
    end

    Kukupa::Models::CaseTask.where(case: c).each do |ct|
      advocates = case_populate_advocate(advocates, ct.author)
      advocates = case_populate_advocate(advocates, ct.assigned_to)

      child_actions = [
        {
          url: "##{ct.anchor}",
          fa_icon: 'fa-external-link',
        }
      ]

      actions =  [
        {
          url: url("/case/#{c}/task/#{ct.id}"),
          fa_icon: 'fa-gear',
        },
      ]

      parent = {
        type: :task,
        id: "CaseTask[#{ct.id}]",
        anchor: ct.anchor,
        creation: ct.creation,
        content: ct.decrypt(:content),
        author: advocates[ct.author.to_s],
        assigned_to: advocates[ct.assigned_to.to_s],
        actions: actions,
      }

      Kukupa::Models::CaseTaskUpdate.where(task: ct.id).each do |ctu|
        advocates = case_populate_advocate(advocates, ctu.author)

        update_type = ctu.decrypt(:update_type)&.strip&.downcase&.to_sym
        update_data = JSON.parse(ctu.data.nil?() ? '{}' : ctu.decrypt(:data))
        update = {type: update_type}

        if update_type == :assign
          advocates = case_populate_advocate(advocates, update_data['to'])
          update[:to] = advocates[update_data['to'].to_s]
        end

        items << {
          type: :task_update,
          id: "CaseTaskUpdate[#{ctu.id}]",
          anchor: ctu.anchor,
          creation: ctu.creation,
          author: advocates[ctu.author.to_s],
          update: update,
          content: parent[:content],
          parent: parent,
          actions: child_actions,
        }
      end

      items << parent
    end

    items.sort { |a, b| b[:creation] <=> a[:creation] }
  end
end
