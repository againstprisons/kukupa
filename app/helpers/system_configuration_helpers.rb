module Kukupa::Helpers::SystemConfigurationHelpers
  def config_keyvalue_entries
    Kukupa::Models::Config.all.map do |e|
      value = e.value.to_s

      [
        e.key,
        {
          :type => e.type,
          :value => value,
          :deprecated => Kukupa::APP_CONFIG_DEPRECATED_ENTRIES[e.key],
          :edit_link => "/system/config/#{e.key}",
        }
      ]
    end.to_h
  end

  def config_mail_entries
    keys = [
      "email-from",
      "email-smtp-host",
      "email-subject-prefix",
    ]

    keys.map do |key|
      e = Kukupa::Models::Config.where(:key => key).first
      next nil unless e

      [
        e.key,
        {
          :type => e.type,
          :value => e.value,
        }
      ]
    end.compact.to_h
  end
end
