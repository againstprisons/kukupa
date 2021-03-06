require 'ostruct'
require 'magentasso'
require 'addressable'

module Kukupa::Helpers::AuthProviderHelpers
  class MagentaProvider < OpenStruct
    def type
      :magenta
    end

    def begin_url
      "/auth/sso/magenta/#{name.downcase}"
    end

    def request
      callback_url = ::Addressable::URI.parse(Kukupa.app_config['base-url'])
      callback_url += "/auth/sso/magenta/#{name.downcase}/callback"

      MagentaSSO::Request.new(
        client_id,
        client_secret,
        nil,
        scopes,
        callback_url.to_s,
      )
    end

    def verify_response(payload, signature)
      MagentaSSO::Response.verify(payload, signature, client_secret)
    end
  end

  def auth_providers_count(opts = {})
    Kukupa.app_config['magenta-providers'].count
  end

  def auth_providers(opts = {})
    providers = {}
    filter_type = [opts[:filter_type]].flatten.compact

    Kukupa.app_config['magenta-providers'].each do |mp|
      data = %w[name friendly_name base_url client_id client_secret scopes].map do |key|
        [key.to_sym, mp[key]]
      end.to_h

      provider = MagentaProvider.new(data)
      providers[provider.name.downcase] = provider
    end

    return providers if filter_type.empty?
    providers.filter { |_, prv| filter_type.include?(prv.type) }
  end
end
