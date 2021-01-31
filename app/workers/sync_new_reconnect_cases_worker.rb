class Kukupa::Workers::SyncNewReconnectCasesWorker
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

    # Get penpal / relationship data from re:connect
    logger.info("Checking our re:connect penpal for new relationships...")
    rc_penpal = helpers.reconnect_penpal(cid: Kukupa.app_config['reconnect-penpal-id'])
    unless rc_penpal.is_a?(Hash) && rc_penpal['success']
      logger.warn("re:connect API response was: #{rc_penpal.inspect}")
      logger.fatal("re:connect API call response not a Hash, or was not successful. Bailing.")
      return
    end
    
    # Get the re:connect IDs of our known cases, so we can exclude those from our search
    known_rc_ids = Kukupa::Models::Case
      .select(:id, :reconnect_id)
      .exclude(reconnect_id: nil)
      .map(&:reconnect_id)
      .map(&:to_s)
      
    # Construct the list of re:connect relationship and penpal IDs that we
    # don't have cases for, and grab the penpal data from re:connect for each
    # of these penpals
    unknown_rels = rc_penpal['relationships'].map do |rel|
      penpal_id = rel['other_party']['id']
      next nil unless penpal_id.positive?
      penpal_id = penpal_id.to_s
      next nil if known_rc_ids.include?(penpal_id)
      
      logger.info("Getting data for re:connect penpal #{penpal_id}...")

      rc_data = helpers.reconnect_penpal(cid: penpal_id)
      unless rc_data.is_a?(Hash) && rc_data['success']
        logger.warn("Failed to get data for re:connect penpal #{penpal_id} - API call response was not successful: #{rc_data.inspect}")
        next nil
      end
      
      {
        rel_id: rel['id'],
        penpal_id: penpal_id,
        rc_data: rc_data,
      }
    end.compact
    
    # Create a new case for each of the new penpals
    unknown_rels.each do |rel|
      c = Kukupa::Models::Case.new(is_open: true, reconnect_id: rel[:penpal_id]).save
      c.encrypt(:first_name, rel[:rc_data]['name'].first)
      c.encrypt(:last_name, rel[:rc_data]['name'].last)
      c.encrypt(:prisoner_number, rel[:rc_data]['prn'])
      
      prison = Kukupa::Models::Prison.where(reconnect_id: rel[:rc_data]['prison'].to_i).first
      if prison
        c.encrypt(:prison, prison.id)
      else
        logger.warn("Prison with re:connect ID #{rel[:rc_data]['prison'].inspect} was not found in the database")
      end

      c.save
      logger.info("Created new case for re:connect penpal #{rel[:penpal_id]} as case ID #{c.id}")
      
      # Regenerate filters
      logger.info("Regenerating filters for case #{c.id}...")
      Kukupa::Models::CaseFilter.clear_filters_for(c)
      Kukupa::Models::CaseFilter.create_filters_for(c)

      rc_penpal_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
      rc_penpal_url += "/system/penpal/#{rel[:penpal_id]}"

      # Add "system" case note saying this case was imported from re:connect
      sysnote = Kukupa::Models::CaseNote.new(case: c.id).save
      sysnote.encrypt(:content, helpers.t(
        :'reconnect_sync/automatic_case_creation',
        force_language: true,
        reconnect_url: Kukupa.app_config['reconnect-url'],
        penpal_id: rel[:penpal_id],
        penpal_url: rc_penpal_url.to_s,
        now: sysnote.creation,
      ))
      sysnote.save
      
      # Trigger a sync for the new case
      Kukupa::Workers::SyncCaseFromReconnectWorker.perform_async(c.id)
      
      # Send the "new imported case" email alert to admins
      c.send_imported_case_email!
      
      logger.info("Done with case #{c.id}!")
    end
  end
end