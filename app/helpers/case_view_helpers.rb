module Kukupa::Helpers::CaseViewHelpers
  def get_renderables(c)
    c = c.id if c.respond_to?(:id)

    items = []

    Kukupa::Models::CaseNote.where(case: c).map do |cn|
      actions =  [
        {
          url: url("/case/#{c}/note/#{cn.id}"),
          fa_icon: 'fa-gear',
        },
      ]

      items << {
        type: :case_note,
        id: "CaseNote[#{cn.id}]",
        case_note: cn,
        creation: cn.creation,
        content: cn.decrypt(:content),
        author: Kukupa::Models::User[cn.author],
        actions: actions,
      }
    end

    Kukupa::Models::CaseSpend.where(case: c).map do |cs|
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

      items << {
        type: :spend,
        id: "CaseSpend[#{cs.id}]",
        case_spend: cs,
        creation: cs.creation,
        amount: cs.decrypt(:amount),
        notes: cs.decrypt(:notes),
        author: Kukupa::Models::User[cs.author],
        approver: Kukupa::Models::User[cs.approver],
        actions: actions,
      }
    end

    items.sort { |a, b| b[:creation] <=> a[:creation] }
  end
end
