class Kukupa::Workers::CaseTimelineReminderWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    to_notify = []
    threshold = Chronic.parse(Kukupa.app_config['timeline-upcoming-notify'])
    entries = Kukupa::Models::CaseTimelineEntry
      .where{date < threshold}
      .where(reminded: nil)
      .order(Sequel.desc(:date))
      .all

    logger.info("Unnotified timeline entries upcoming by threshold: #{entries.count}")

    entries.each do |entry|
      logger.info("Entry #{entry.id}: starting")

      case_obj = Kukupa::Models::Case[entry.case]
      entry_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      entry_url += "/case/#{case_obj.id}/timeline##{entry.anchor}"
      entry_name = entry.decrypt(:name)
      
      # Send email to all assignees of case
      begin
        email = Kukupa::Models::EmailQueue.new_from_template("timeline_upcoming", {
          case_obj: case_obj,
          entry_obj: entry,
          entry_url: entry_url.to_s,
          entry_name: entry_name,
        })

        email.encrypt(:subject, "Reminder: Upcoming timeline entry") # TODO: tl this
        email.encrypt(:recipients, JSON.generate({
          "mode": "list_uids",
          "uids": case_obj.get_assigned_advocates,
        }))

        email.queue_status = 'queued'
        email.save
      end

      logger.info("Entry #{entry.id}: complete, marking as reminded")
      entry.reminded = Sequel.function(:NOW)
      entry.save
    end
  end
end
