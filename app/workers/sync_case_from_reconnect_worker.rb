require 'addressable'
require 'typhoeus'

class Kukupa::Workers::SyncCaseFromReconnectWorker
  include Sidekiq::Worker

  def perform(cid)
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    case_obj = Kukupa::Models::Case[cid.to_i]
    if case_obj.nil? || case_obj&.reconnect_id.to_i.zero?
      logger.fatal("Case #{cid} does not exist or has no re:connect association")
      return
    end

    parsed_window = Chronic.parse(Kukupa.app_config['reconnect-sync-after'], guess: true)
    unless case_obj.reconnect_last_sync.nil?
      if case_obj.reconnect_last_sync > parsed_window
        logger.warn("Case #{case_obj.id} last synced within window, not syncing")
        return
      end
    end

    logger.info("Setting last sync timestamp for #{case_obj.id}")
    case_obj.reconnect_last_sync = Sequel.function(:NOW)
    case_obj.save

    logger.info("Queueing sync jobs for case #{case_obj.id}")
    Kukupa::Workers::SyncCasePenpalFromReconnectWorker.perform_async(case_obj.id)
    Kukupa::Workers::SyncCaseMailFromReconnectWorker.perform_async(case_obj.id)
  end
end
