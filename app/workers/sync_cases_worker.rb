class Kukupa::Workers::SyncCasesWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    if Kukupa.app_config['reconnect-api-key'].nil?
      logger.fatal("No re:connect API key present, bailing")
      return
    end

    ids = Kukupa::Models::Case
      .select(:id, :reconnect_id)
      .exclude(reconnect_id: nil)
      .map(&:id)

    logger.info("Queueing sync for #{ids.count} cases")

    ids.each do |cid|
      Kukupa::Workers::SyncCaseFromReconnectWorker.perform_async(cid)
    end
  end
end
