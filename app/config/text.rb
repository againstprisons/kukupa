module Kukupa::Config::Text
  module_function

  def order
    -10000
  end

  def accept?(_key, type)
    type == :text
  end

  def parse(value)
    value = value.force_encoding(Encoding::UTF_8)
    value.gsub!("@SITEDIR@", Kukupa.site_dir) if Kukupa.site_dir

    {
      :data => value
    }
  end
end
