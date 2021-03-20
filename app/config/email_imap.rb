module Kukupa::Config::EmailImap
  module_function

  def order
    100
  end

  def accept?(key, _type)
    key == "email-imap-host"
  end

  def parse(value)
    if value.nil? || value.strip.empty?
      return {
        :warning => "Invalid value #{value.inspect}",
        :data => {
          :type => :none,
        },
        :stop_processing_here => true,
      }
    end

    if value == 'none'
      return {
        :data => {
          :type => :none,
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
          :type => :none,
        },
        :stop_processing_here => true,
      }
    end

    opts = {
      :address => uri.host,
      :port => uri.port,

      :enable_ssl => uri.query_values ? uri.query_values["ssl"] == 'yes' : false,
      :enable_starttls => uri.query_values ? uri.query_values["starttls"] == 'yes' : false,

      :authentication => uri.query_values ? uri.query_values["authentication"]&.strip&.downcase : nil,
      :user_name => Addressable::URI.unencode(uri.user || ''),
      :password => Addressable::URI.unencode(uri.password || ''),
    }

    {
      :data => opts,
      :stop_processing_here => true,
    }
  end

  def process(data)
    if data[:type] == :none
      return Mail.defaults do
        retriever_method :test, {}
      end
    end

    Mail.defaults do
      retriever_method :imap, data
    end
  end
end
