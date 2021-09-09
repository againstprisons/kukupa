class Kukupa::Workers::CaseUnassignedNewRequestWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    # For each case, check whether it has any assigned advocates.
    # If it doesn't, grab it's ID, so we can look it up in the next step
    logger.info("Getting cases with no advocates...")
    case_ids = Kukupa::Models::Case
      .select(:id, :is_open)
      .where(is_open: true)
      .all
      .map do |c|
        adv_count = Kukupa::Models::CaseAssignedAdvocate
          .where(case: c.id)
          .count

        next nil if adv_count.positive?
        c.id
      end.compact.uniq

    # For each case that we grabbed IDs for before, check if they have:
    #
    # - any new prisoner correspondence
    # - any new outside requests
    #
    # If they don't, ignore the case.
    logger.info("Checking request timestamps for #{case_ids.count} cases...")
    cases = case_ids.map do |cid|
      case_obj = Kukupa::Models::Case[cid]
      next nil unless case_obj
      timestamps = []

      # Check correspondence
      timestamps << Kukupa::Models::CaseCorrespondence
        .select(:id, :case, :creation)
        .where(case: case_obj.id)
        .reverse(:creation)
        .first
        &.creation

      # Check outside requests
      timestamps << Kukupa::Models::CaseNote
        .select(:id, :case, :creation, :is_outside_request)
        .where(case: case_obj.id, is_outside_request: true)
        .reverse(:creation)
        .first
        &.creation

      # If no timestamps, ignore this case
      timestamps.compact!
      next nil if timestamps.empty?

      # Get latest timestamp, if case has been updated since then, ignore
      request_ts = timestamps.sort.last
      next nil if case_obj.last_updated > request_ts

      {
        case: case_obj,
        request_ts: request_ts,
      }
    end.compact

    # Now that we have our list of cases, clear the existing cases in the
    # CaseUnassignedNewRequest table, and insert our updated ones
    Kukupa::Models::CaseUnassignedNewRequest.select.delete
    new_requests = cases.map do |cd|
      cnr = Kukupa::Models::CaseUnassignedNewRequest.new({
        case: cd[:case].id,
        request_ts: cd[:request_ts],
      })

      cnr.save
    end

    logger.info("Generated #{new_requests.count} CaseUnassignedNewRequest objects")
  end
end

