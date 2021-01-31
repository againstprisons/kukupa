require 'addressable'
require 'typhoeus'

class Kukupa::Workers::SyncCasePenpalFromReconnectWorker
  include Sidekiq::Worker

  def perform(cid)
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    @case = Kukupa::Models::Case[cid.to_i]
    unless @case
      logger.fatal("No case with the given case ID, bailing")
      return
    end

    unless @case.reconnect_id.to_i.positive?
      logger.fatal("Case #{@case.id} has no re:connect link, bailing")
      return
    end

    if Kukupa.app_config['reconnect-api-key'].nil?
      logger.fatal("No re:connect API key present, bailing")
      return
    end

    logger.info("Starting re:connect sync for case #{@case.id}")

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/penpal'
    logger.info("Hitting API endpoint: #{api_url.to_s.inspect}")

    req_opts = {
      method: :post,
      body: {
        cid: @case.reconnect_id,
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

    prison = Kukupa::Models::Prison.where(reconnect_id: data['prison'].to_i).first
    if prison
      @case.encrypt(:prison, prison.id)
    else
      logger.warn("Prison with re:connect ID #{data['prison'].inspect} was not found in the database")
    end

    @case.encrypt(:prisoner_number, data['prn'])
    @case.encrypt(:first_name, data['name'][0])
    @case.encrypt(:middle_name, data['name'][1])
    @case.encrypt(:last_name, data['name'][2])
    if data['pseudonym'] == data['name'][0]
      @case.pseudonym = nil
    else
      @case.encrypt(:pseudonym, data['pseudonym'])
    end

    @case.reconnect_last_sync = Sequel.function(:NOW)
    @case.save
    logger.info("Updated case #{@case.id} successfully")
  end
end
