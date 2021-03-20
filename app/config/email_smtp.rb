module Kukupa::Config::EmailSmtp
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "email-smtp-host"
  end

  def parse(value)
    if value.nil? || value.strip.empty?
      return {
        :warning => "Invalid value #{value.inspect}",
        :data => {
          :type => :logger,
        },
        :stop_processing_here => true,
      }
    end

    if value == 'logger'
      return {
        :data => {
          :type => :logger,
        },
        :stop_processing_here => true,
      }
    end

    uri = nil
    begin
      uri = Addressable::URI.parse(value)
    rescue => e
      return {
        :warning => "Exception parsing URL: #{e.class.name}: #{e}",
        :data => {
          :type => :logger,
        },
        :stop_processing_here => true,
      }
    end

    opts = {
      :address => uri.host,
      :port => uri.port,

      :enable_starttls_auto => uri.query_values ? uri.query_values["starttls"] == 'yes' : false,
      :enable_tls => uri.query_values ? uri.query_values["tls"] == 'yes' : false,
      :enable_ssl => uri.query_values ? uri.query_values["ssl"] == 'yes' : false,
      :openssl_verify_mode => uri.query_values ? uri.query_values["verify_mode"]&.strip&.upcase || 'PEER' : 'PEER',
      :ca_path => ENV["SSL_CERT_DIR"],
      :ca_file => ENV["SSL_CERT_FILE"],

      :authentication => uri.query_values ? uri.query_values["authentication"]&.strip&.downcase || 'plain' : 'plain',
      :user_name => Addressable::URI.unencode(uri.user || ''),
      :password => Addressable::URI.unencode(uri.password || ''),
    }

    {
      :data => opts,
      :stop_processing_here => true,
    }
  end

  def process(data)
    if data[:type] == :logger
      return Mail.defaults do
        delivery_method :logger
      end
    end

    Mail.defaults do
      delivery_method :smtp, data
    end
  end
end
