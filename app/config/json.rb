module Kukupa::Config::JSON
  module_function

  def order
    -10000
  end

  def accept?(key, type)
    type == :json
  end

  def parse(value)
    begin
      {
        :data => JSON.parse(value),
      }
    rescue => e
      {
        :warning => "Failed to parse JSON: #{e.class.name}: #{e}",
        :data => nil,
      }
    end
  end
end
