class Kukupa::Models::CaseSpendUpdate < Sequel::Model
  def anchor
    "CaseSpendUpdate-#{self.id}"
  end

  def parent
    Kukupa::Models::CaseSpend[self.spend]
  end

  def renderables(opts = {})
    items = []
    parent = self.parent

    actions = [
      {
        url: "##{parent.anchor}",
        fa_icon: 'fa-external-link',
      }
    ]

    begin
      data = JSON.parse(self.decrypt(:data) || '{}').map do |k, v|
        [k.to_sym, v]
      end.to_h
    rescue
      data = {}
    end

    data.merge!({
      type: self.update_type.to_sym,
    })

    items << {
      type: :spend_update,
      id: "CaseSpendUpdate[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      author: [:user, self.author],
      parent: parent,
      update: data,
      actions: actions,
    }

    items
  end
end
