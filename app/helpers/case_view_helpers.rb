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

  def get_renderables(c, opts = {})
    c = c.id if c.respond_to?(:id)

    cuser = current_user
    advocates = {}

    items = []

    Kukupa::Models::CaseNote.where(case: c).each do |cn|
      child_actions = [
        {
          url: "##{cn.anchor}",
          fa_icon: 'fa-external-link',
        }
      ]

      actions =  [
        {
          url: url("/case/#{c}/note/#{cn.id}"),
          fa_icon: 'fa-gear',
        },
      ]

      begin
        metadata = JSON.parse(cn.decrypt(:metadata) || '{}').map do |k, v|
          [k.to_sym, v]
        end.to_h
      rescue
        metadata = {}
      end

      advocates = case_populate_advocate(advocates, cn.author)

      parent = {
        type: :note,
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

      if opts[:include_updates]
        Kukupa::Models::CaseNoteUpdate.where(note: cn.id).each do |cnu|
          advocates = case_populate_advocate(advocates, cnu.author)

          begin
            data = JSON.parse(cnu.decrypt(:data) || '{}').map do |k, v|
              [k.to_sym, v]
            end.to_h
          rescue
            data = {}
          end

          data.merge!({
            type: cnu.update_type.to_sym,
          })

          items << {
            type: :note_update,
            id: "CaseNoteUpdate[#{cnu.id}]",
            anchor: cnu.anchor,
            case_note: cn,
            creation: cnu.creation,
            author: advocates[cnu.author.to_s],
            parent: parent,
            update: data,
            actions: child_actions,
          }
        end
      end

      items << parent
    end

    Kukupa::Models::CaseSpend.where(case: c).each do |cs|
      child_actions = [
        {
          url: "##{cs.anchor}",
          fa_icon: 'fa-external-link',
        }
      ]

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

      parent = {
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

      if opts[:include_updates]
        Kukupa::Models::CaseSpendUpdate.where(spend: cs.id).each do |csu|
          advocates = case_populate_advocate(advocates, csu.author)

          begin
            data = JSON.parse(csu.decrypt(:data) || '{}').map do |k, v|
              [k.to_sym, v]
            end.to_h
          rescue
            data = {}
          end

          data.merge!({
            type: csu.update_type.to_sym,
          })

          items << {
            type: :spend_update,
            id: "CaseSpendUpdate[#{csu.id}]",
            anchor: csu.anchor,
            case_spend: cs,
            creation: csu.creation,
            author: advocates[csu.author.to_s],
            parent: parent,
            update: data,
            actions: child_actions,
          }
        end
      end

      items << parent
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

        begin
          data = JSON.parse(ctu.decrypt(:data) || '{}').map do |k, v|
            [k.to_sym, v]
          end.to_h
        rescue
          data = {}
        end

        data.merge!({
          type: ctu.update_type.to_sym,
        })

        if data[:type] == :assign
          advocates = case_populate_advocate(advocates, update_data[:to])
          update_data[:to] = advocates[update_data[:to].to_s]
        end

        items << {
          type: :task_update,
          id: "CaseTaskUpdate[#{ctu.id}]",
          anchor: ctu.anchor,
          creation: ctu.creation,
          author: advocates[ctu.author.to_s],
          update: data,
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
