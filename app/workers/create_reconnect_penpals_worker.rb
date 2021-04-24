class Kukupa::Workers::CreateReconnectPenpalsWorker
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
    
    unless Kukupa.app_config['reconnect-create-penpals']
      logger.fatal("Configuration key reconnect-create-penpals is not enabled, bailing")
      return
    end

    cases = Kukupa::Models::Case
      .where(type: 'case', reconnect_id: nil)
      .exclude(prisoner_number: nil, prison: nil)

    logger.info("Creating penpals for #{cases.count} cases")

    cases.each do |case_obj|
      ret = case_obj.create_in_reconnect!
      unless ret == true
        logger.warn("Return value for case #{case_obj.id}: #{ret.inspect}")
      end
    end
  end
end
