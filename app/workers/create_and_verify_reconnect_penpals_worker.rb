class Kukupa::Workers::CreateAndVerifyReconnectPenpalsWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    helpers = Class.new do
      extend Kukupa::Helpers::LanguageHelpers
      extend Kukupa::Helpers::ReconnectHelpers
    end

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

    case_count = {total: 0, error: 0, skip: 0}
    Kukupa::Models::Case.where(type: 'case').each do |case_obj|
      case_prn = case_obj.decrypt(:prisoner_number)&.strip
      case_prn = nil if case_prn&.empty?
      case_prison = Kukupa::Models::Prison[case_obj.decrypt(:prison).to_i]

      if case_prn.nil?
        logger.info("Case #{case_obj.id}: No PRN, skipping")
        case_count[:skip] += 1

      elsif case_prison.nil? || case_prison&.reconnect_id.to_i.zero?
        logger.info("Case #{case_obj.id}: No prison (or prison has no re:connect ID), skipping")
        case_count[:skip] += 1

      else
        create_opts = {}
        if case_obj.reconnect_id.to_i.positive?
          reconnect_data = helpers.reconnect_penpal(cid: case_obj.reconnect_id.to_i)
          if reconnect_data['success'] && reconnect_data['id'].to_i == case_obj.reconnect_id.to_i
            logger.info("Case #{case_obj.id}: Verified existing penpal: #{case_obj.reconnect_id}")
            create_opts[:skip_penpal_creation] = true
          end
        end

        logger.info("Case #{case_obj.id}: Calling with #{create_opts.inspect}")

        ret = case_obj.create_in_reconnect!(create_opts)
        if ret == true
          logger.info("Case #{case_obj.id}: ok")
        else
          logger.warn("Case #{case_obj.id}: Return value #{ret.inspect}")
          case_count[:error] += 1
        end
      end
      
      case_count[:total] += 1
      if case_count[:total] % 10 == 0
        logger.info("Processed #{case_count[:total]} so far")
      end
    end
    
    logger.info("Done: #{case_count[:total]} total, #{case_count[:skip]} skipped, #{case_count[:error]} errored")
  end
end
