module Kukupa::Config::Number
  module_function

  def order
    -10000
  end

  def accept?(_key, type)
    type == :number
  end

  def parse(value)
    {
      :data => value.to_i
    }
  rescue
    {
      :warning => "Failed to parse #{value.inspect} as a number",
      :data => 0,
    }
  end
end
