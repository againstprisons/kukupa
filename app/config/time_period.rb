module Kukupa::Config::TimePeriod
  module_function

  def order
    100
  end

  def accept?(_key, type)
    type == :time_period
  end

  def parse(value)
    loaded = Chronic.parse(value)
    if loaded.nil?
      return {
        :warning => "Failed to parse time period",
        :data => nil,
      }
    end

    {:data => value}
  end
end
