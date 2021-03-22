class Kukupa::Models::MailTemplate < Sequel::Model
  def self.template_list(case_obj, opts = {})
    self.all.map do |tpl|
      url = nil
      if case_obj
        url = Addressable::URI.parse(url("/case/#{case_obj.id}/correspondence/send"))
        url.query_values = {tpl: tpl.id}
        url.query_values[:email] = opts[:email] if opts[:email]
      end

      {
        id: tpl.id,
        name: tpl.decrypt(:name),
        enabled: tpl.enabled,
        url: url,
      }
    end
  end
end
