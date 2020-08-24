module Kukupa::Config::Bool
  module_function

  def order
    -10000
  end

  def accept?(_key, type)
    type == :bool
  end

  def parse(value)
    {
      :data => (value == 'yes')
    }
  end
end
