require 'addressable'
require 'typhoeus'

class Kukupa::Workers::SyncCaseMailFromReconnectWorker
  include Sidekiq::Worker

  def perform(case_id)
    case_id = case_id.to_i
    unless case_id.positive?
      logger.fatal("No case ID provided, bailing")
      return
    end

    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    if Kukupa.app_config['reconnect-api-key'].nil?
      logger.fatal("No re:connect API key present, bailing")
      return
    end

    case_obj = Kukupa::Models::Case[case_id]
    unless case_obj.reconnect_id.to_i.positive?
      logger.fatal("Case #{case_obj.id} has no re:connect association, bailing")
      return
    end

    logger.info("Getting re:connect relationships for re:connect penpal #{case_obj.reconnect_id}")

    rl_api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url']) + '/api/penpal'
    logger.info("Hitting API endpoint: #{rl_api_url.to_s.inspect}")

    rl_req_opts = {
      method: :post,
      body: {
        cid: case_obj.reconnect_id,
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    # Make the request
    rl_response = Typhoeus::Request.new(rl_api_url.to_s, rl_req_opts).run
    unless rl_response.success?
      logger.fatal("Non-success from API: #{rl_response.inspect}")
      return
    end

    # Parse JSON
    begin
      rl_data = JSON.parse(rl_response.body)
    rescue => e
      logger.fatal("Couldn't parse JSON from response: #{e.inspect}\nRequest body:#{rl_response.body.inspect}")
      return
    end

    # Check request success
    unless rl_data['success']
      logger.fatal("Non-success from API in body: #{rl_data.inspect}")
      return
    end

    # Search returned relationships for the relationship with the advocacy
    # profile (app_config['reconnect-penpal-id'])
    relationship = rl_data['relationships'].find do |r|
      r['other_party']['id'].to_s == Kukupa.app_config['reconnect-penpal-id'].to_s
    end

    unless relationship
      logger.fatal("No relationship found with the advocacy penpal in re:connect")
      return
    end

    # Get timestamp of last correspondence
    last_ts = Kukupa::Models::CaseCorrespondence
      .select(:case, :file_type, :creation)
      .where(case: case_obj.id, file_type: 'reconnect')
      .reverse(:creation)
      .first
      &.creation
      .to_i

    if last_ts.zero?
      logger.info("No previous correspondence for this case.")
    end

    logger.info("Getting mail in re:connect relationship #{relationship['id']} since #{last_ts}")

    c_api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url']) + '/api/correspondence/list'
    logger.info("Hitting API endpoint: #{c_api_url.to_s.inspect}")

    c_req_opts = {
      method: :post,
      body: {
        cid: relationship['id'],
        since: last_ts,
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    # Make the request
    c_response = Typhoeus::Request.new(c_api_url.to_s, c_req_opts).run
    unless c_response.success?
      logger.fatal("Non-success from API: #{c_response.inspect}")
      return
    end

    # Parse JSON
    begin
      c_data = JSON.parse(c_response.body)
    rescue => e
      logger.fatal("Couldn't parse JSON from response: #{e.inspect}\nRequest body:#{c_response.body.inspect}")
      return
    end

    # Check request success
    unless c_data['success']
      logger.fatal("Non-success from API in body: #{c_data.inspect}")
      return
    end

    # Iterate over correspondence, checking if each correspondence entry
    # exists in the database, creating it if it doesn't.
    count_new = 0
    entries = c_data['correspondence'].map do |c|
      cm = Kukupa::Models::CaseCorrespondence.find_or_create(reconnect_id: c['id'].to_i) do |cm|
        # The block of find_or_create is only called if this is a new entry,
        # so use that to count the number of created entries.
        count_new += 1

        cm.case = case_obj.id
        cm.creation = Chronic.parse c['creation']

        cm.file_type = 'reconnect'
        cm.file_id = c['file_id']
        cm.sent_by_us = (c['sending_penpal'].to_s == Kukupa.app_config['reconnect-penpal-id'].to_s)

        # send email alert to case assigned advocates (or site admins if no assigned advocate)
        cm.send_incoming_alert_email!
        cm.create_incoming_mail_task!
      end

      # Change all external sent-by-us correspondence to "approved"
      # (since it'll only ever be external if it's already been sent)
      if cm.file_type == 'reconnect' && cm.sent_by_us
        cm.approved = true
        cm.has_been_sent = true
      end

      cm.save
    end

    case_obj.reconnect_last_sync = Sequel.function(:NOW)
    case_obj.save

    logger.info("Sync successful: updated #{entries.count - count_new}, created #{count_new}")
  end
end
