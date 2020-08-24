module Kukupa::Config::NilEmpty
  module_function

  def order
    0
  end

  def accept?(_key, type)
    type == :text
  end

  def parse(value)
    if value.nil? || value.strip.empty?
      {
        :data => nil,
      }
    else
      {
        :data => value,
      }
    end
  end
end
