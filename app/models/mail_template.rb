class Kukupa::Models::MailTemplate < Sequel::Model
  def self.template_list(case_obj, opts = {})
    self.all.map do |tpl|
      url = nil
      if case_obj
        url = Addressable::URI.parse("/case/#{case_obj.id}/correspondence/send")
        url.query_values = opts.merge({tpl: tpl.id})
      end

      {
        id: tpl.id,
        name: tpl.decrypt(:name),
        group: tpl.decrypt(:group),
        enabled: tpl.enabled,
        url: url,
      }
    end
  end
end
