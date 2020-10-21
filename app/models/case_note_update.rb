class Kukupa::Models::CaseNoteUpdate < Sequel::Model
  def anchor
    "CaseNoteUpdate-#{self.id}"
  end

  def parent
    Kukupa::Models::CaseNote[self.note]
  end

  def renderables(opts = {})
    items = []
    parent = self.parent

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

    actions =  [
      {
        url: "##{parent.anchor}",
        fa_icon: 'fa-external-link',
      },
    ]

    items << {
      type: :note_update,
      id: "CaseNoteUpdate[#{self.id}]",
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
