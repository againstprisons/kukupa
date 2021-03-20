class Kukupa::Workers::SyncIncomingEmailWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    unless Kukupa.app_config['feature-case-correspondence-email']
      logger.fatal("Case correspondence email feature flag (`feature-case-correspondence-email`) is disabled, dying")
      return
    end

    count = {retrieved: 0, populated: 0, errored: 0}
    Mail.find_and_delete(what: :first, count: 20, search_charset: 'UTF-8') do |message|
      count[:retrieved] += 1

      ccobj = Kukupa::Models::CaseCorrespondence.new_from_incoming_email(message)
      if ccobj
        count[:populated] += 1
        logger.info("Message #{message.message_id}: populated CaseCorrespondence[#{ccobj.id}]")

        # send new correspondence alert
        ccobj.send_incoming_alert_email!

        # delete message if successfully populated
        message.mark_for_delete = true

      else
        count[:errored] += 1
        logger.warn("Message #{message.message_id}: parse did not return CaseCorrespondence :(")
      end
    end

    logger.info("Email sync done: #{count[:retrieved]} retrieved, #{count[:populated]} populated, #{count[:errored]} errored")
  end
end
