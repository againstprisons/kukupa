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

      begin
        metadata = JSON.parse(cn.decrypt(:metadata) || '{}')
        metadata = metadata.keys.map do |k|
          [k.to_sym, metadata[k]]
        end.to_h
      rescue
        metadata = {}
      end

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
        anchor: cs.anchor,
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
