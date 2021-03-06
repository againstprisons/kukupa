module Kukupa::Config::MagentaProviders
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "magenta-providers"
  end

  def parse(value)
    unless value.is_a?(Array)
      return {
        warning: "#{value.inspect} is not an Array",
        data: [],
        stop_processing_here: true,
      }
    end

    warnings = []
    value.each_with_index do |mp, idx|
      unless mp.is_a?(Hash)
        warnings << "[#{idx}] is not a Hash"
        next
      end

      unless mp.key?("name")
        warnings << "[#{idx}] has no name"
        next
      end

      %w[friendly_name base_url client_id client_secret scopes].each do |key|
        unless mp.key?(key)
          warnings << "#{mp["name"].inspect} has no #{key.inspect}"
        end
      end
    end

    unless warnings.empty?
      return {
        warning: warnings.join(", "),
        data: [],
        stop_processing_here: true,
      }
    end

    {
      data: value,
      stop_processing_here: true,
    }
  end
end
