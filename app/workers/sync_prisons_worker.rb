require 'addressable'
require 'typhoeus'

class Kukupa::Workers::SyncPrisonsWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    if Kukupa.app_config['reconnect-api-key'].nil?
      logger.fatal("No re:connect API key present, bailing")
      return
    end

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/prisons'
    logger.info("Hitting API endpoint: #{api_url.to_s.inspect}")

    req_opts = {
      method: :post,
      body: {
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    unless response.success?
      logger.fatal("Non-success from API: #{response.inspect}")
      return
    end

    begin
      data = JSON.parse(response.body)
    rescue => e
      logger.fatal("Couldn't parse JSON from response: #{ret.inspect}")
      return
    end

    unless data['prisons']&.count&.positive?
      logger.fatal("No prisons in API response")
      return
    end

    count = {created: 0, updated: 0}
    data['prisons'].each do |pr|
      model = Kukupa::Models::Prison.where(reconnect_id: pr['id']).first
      if model
        count[:updated] += 1
      else
        model = Kukupa::Models::Prison.new(reconnect_id: pr['id']).save
        count[:created] += 1
      end

      model.encrypt(:name, pr['name'])
      model.encrypt(:physical_address, pr['address'])
      model.encrypt(:email_address, pr['email'])
      model.save
    end

    logger.info("Created #{count[:created]} new prisons, updated #{count[:updated]} existing")
  end
end
