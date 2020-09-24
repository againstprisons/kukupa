module Kukupa::Config::InviteExpiry
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "invite-expiry"
  end

  def parse(value)
    loaded = Chronic.parse(value)
    if loaded.nil?
      return {
        :warning => "Failed to parse time period",
        :data => Kukupa::APP_CONFIG_ENTRIES['invite-expiry'][:default],
      }
    end

    {:data => value}
  end
end
