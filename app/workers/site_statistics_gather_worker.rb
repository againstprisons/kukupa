class Kukupa::Workers::SiteStatisticsGatherWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    # Get site-wide statistics
    logger.info("Gathering site-wide statistics…")
    global = Kukupa::Models::SiteStatistics.new(
      date: DateTime.now,
      user_count: Kukupa::Models::User.count,
      case_count: Kukupa::Models::Case.count,
      spend_count: Kukupa::Models::CaseSpend.count,
      spend_total: Kukupa::Models::CaseSpend.select(:id, :amount).map{|x| x.decrypt(:amount).to_f}.sum.to_i,
      correspondence_count: Kukupa::Models::CaseCorrespondence.count,
      note_count: Kukupa::Models::CaseNote.count,
      task_count: Kukupa::Models::CaseTask.count,
    ).save
    logger.info("Site-wide statistics created: SiteStatistics[#{global.id}]")

    # Get all cases and store them in a hash by their type + purpose
    logger.info("Gathering cases…")
    cases = {}
    Kukupa::Models::Case.each do |case_obj|
      case_obj.get_purposes.map(&:to_sym).each do |cp|
        key = [case_obj.type.to_sym, cp]
        cases[key] ||= []
        cases[key] << case_obj
      end
    end

    # For each mapping of case type + case purpose, create a SiteCaseStatistics
    # entry with the totals for that mapping
    per_type_purpose = cases.keys.map do |key|
      logger.info("Processing type/purpose #{key.inspect}")

      case_ids = cases[key].map(&:id)
      values = {
        date: DateTime.now,
        case_type: key.first,
        case_purpose: key.last,
        case_count: cases[key].count,
      }

      # Get spends
      spends = Kukupa::Models::CaseSpend.where(case: case_ids).select(:id, :case, :amount).all
      values[:spend_count] = spends.count
      values[:spend_total] = spends.map{|x| x.decrypt(:amount).to_f}.sum.to_i

      # Get correspondence count
      values[:correspondence_count] = Kukupa::Models::CaseCorrespondence.where(case: case_ids).count

      # Get note count
      values[:note_count] = Kukupa::Models::CaseNote.where(case: case_ids).count

      # Get task count
      values[:task_count] = Kukupa::Models::CaseTask.where(case: case_ids).count

      # Create the SiteCaseStatistics entry
      obj = Kukupa::Models::SiteCaseStatistics.new(values).save
      logger.info("Entry for #{key.inspect} created: SiteCaseStatistics[#{obj.id}]")
    end
  end
end
