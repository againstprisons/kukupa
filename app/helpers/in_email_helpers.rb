require 'erb'
require 'tilt'

module Kukupa::Helpers::InEmailHelpers
  def button(url, text)
    styles = {
      :container => "text-align:center",
      :button => (
        "display:inline-block;padding:0.5em 1em;margin:0.5em;" +
        "background:#0078e7;color:#fff;border:1px solid #0078e7;" +
        "border-radius:3px;text-decoration:none"
      ),
    }

    content = (
      '<p style="<%= styles[:container] %>">' +
      '  <a href="<%= url %>" style="<%= styles[:button] %>"><%= text %></a>' +
      '</p>'
    )

    values = OpenStruct.new({:text => text, :url => url, :styles => styles})
    template = Tilt::ERBTemplate.new() { content }
    template.render(values)
  end
end
