class Kukupa::Models::CaseTaskUpdate < Sequel::Model
  def anchor
    "CaseTaskUpdate-#{self.id}"
  end

  def parent
    Kukupa::Models::CaseTask[self.task]
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

    update_item = {
      type: :task_update,
      id: "CaseTaskUpdate[#{self.id}]",
      anchor: self.anchor,
      creation: self.creation,
      author: [:user, self.author],
      parent: parent,
      content: parent.decrypt(:content),
      update: data,
      actions: actions,
    }

    if data[:type] == :assign
      update_item[:assigned_to] = [:user, data[:to].to_i]
    end

    items << update_item
    items
  end
end
