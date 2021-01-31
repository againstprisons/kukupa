class Kukupa::Models::MailTemplate < Sequel::Model
  def self.template_list
    self.all.map do |tpl|
      {
        id: tpl.id,
        name: tpl.decrypt(:name),
        enabled: tpl.enabled,
      }
    end
  end
end