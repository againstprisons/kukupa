module Kukupa::Helpers::SystemOutsideRequestHelpers
  def config_key_json(key)
    entry = Kukupa::Models::Config.where(key: key).first
    return [] unless entry
    JSON.parse(entry.value)
  end
end
