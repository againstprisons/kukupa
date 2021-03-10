class Kukupa::Workers::SyncCasesWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    %w[reconnect-api-key reconnect-url reconnect-penpal-id].each do |k|
      unless Kukupa.app_config[k]
        logger.fatal("Configuration key #{k} is not present, bailing")
        return
      end
    end

    ids = Kukupa::Models::Case
      .select(:id, :type, :reconnect_id)
      .where(type: 'case')
      .exclude(reconnect_id: nil)
      .map(&:id)

    logger.info("Queueing sync for #{ids.count} cases")

    ids.each do |cid|
      Kukupa::Workers::SyncCaseFromReconnectWorker.perform_async(cid)
    end
  end
end
