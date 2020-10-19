class Kukupa::Workers::FilterRefreshWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    ###
    # enable maintenance mode
    ###

    logger.info("Enabling maintenance mode")
    maint_cfg = Kukupa::Models::Config.where(:key => 'maintenance').first
    unless maint_cfg
      maint_cfg = Kukupa::Models::Config.new(:key => 'maintenance', :type => 'bool', :value => 'no')
    end
    maint_enabled = maint_cfg.value == 'yes'
    maint_cfg.value = 'yes'
    maint_cfg.save

    ###
    # penpal filters
    ###

    logger.info("Refreshing case filters...")

    pp_count = {:cases => 0, :filters => 0}
    Kukupa::Models::Case.each do |cs|
      if pp_count[:cases] % 10 == 0
        logger.info("Refreshing: processed #{pp_count[:cases]} so far")
      end

      begin
        Kukupa::Models::CaseFilter.clear_filters_for(cs)
        filters = Kukupa::Models::CaseFilter.create_filters_for(cs)
        pp_count[:filters] += filters.length
      rescue => e
        logger.warn("Refreshing failed for case ID #{cs.id}: #{e.class.name}: #{e.message}")
      end

      pp_count[:cases] += 1
    end

    logger.info("Generated #{pp_count[:filters]} filters for #{pp_count[:cases]} cases.")

    ###
    # fix task update type values
    # TODO: this is temporary, remove this later!
    ###

    ctu_valid_types = %w[assign complete]
    Kukupa::Models::CaseTaskUpdate.all.each do |ctu|
      unless ctu_valid_types.include?(ctu.update_type)
        logger.info("Decrypting update_type on CaseTaskUpdate[#{ctu.id}]")
        update_type = ctu.decrypt(:update_type)&.downcase&.to_s
        ctu.update_type = update_type
        ctu.save
      end
    end

    ###
    # disable maintenance mode if it wasn't already enabled
    ###

    if maint_enabled
      logger.info("Not disabling maintenance mode as it was enabled when worker started")
    else
      logger.info("Disabling maintenance mode")
      maint_cfg.value = 'no'
      maint_cfg.save
    end
  end
end
