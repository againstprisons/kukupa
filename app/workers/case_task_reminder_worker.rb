class Kukupa::Workers::CaseTaskReminderWorker
  include Sidekiq::Worker

  def perform
    Kukupa.initialize if Kukupa.app.nil?
    Kukupa.app_config_refresh(:force => true)

    to_notify = []
    threshold = Chronic.parse(Kukupa.app_config['task-overdue-notify'])
    tasks = Kukupa::Models::CaseTask
      .where(completion: nil)
      .where{creation < threshold}
      .order(Sequel.desc(:creation))
      .all

    logger.info("Uncompleted tasks with creation older than threshold: #{tasks.count}")

    tasks.each do |task|
      if task.last_updated < threshold
        to_notify << task
      end
    end

    logger.info("Unnotified task count: #{to_notify.count}")

    to_notify.each do |task|
      logger.info("Task #{task.id}: starting")

      case_obj = Kukupa::Models::Case[task.case]
      case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      case_url += "/case/#{case_obj.id}/view"

      content = task.decrypt(:content)
      assignee = Kukupa::Models::User[task.assigned_to]
      assignee_name = assignee&.decrypt(:name) || 'unknown user'

      # Send email to assignee
      begin
        email = Kukupa::Models::EmailQueue.new_from_template("task_overdue", {
          case_obj: case_obj,
          case_url: case_url.to_s,
          task_obj: task,
          content: content,
          assignee: assignee,
          assignee_name: assignee_name,
        })

        email.encrypt(:subject, "Reminder: Task assigned to you is overdue") # TODO: tl this
        email.encrypt(:recipients, JSON.generate({
          "mode": "list_uids",
          "uids": [
            assignee.id,
          ],
        }))

        email.queue_status = 'queued'
        email.save
      end

      # Send email to admins
      begin
        email = Kukupa::Models::EmailQueue.new_from_template("task_overdue", {
          case_obj: case_obj,
          case_url: case_url.to_s,
          task_obj: task,
          content: content,
          assignee: assignee,
          assignee_name: assignee_name,
        })

        email.encrypt(:subject, "Reminder: Task is overdue") # TODO: tl this
        email.encrypt(:recipients, JSON.generate({
          "mode": "roles",
          "roles": [
            "case:alerts",
          ],
        }))

        email.queue_status = 'queued'
        email.save
      end

      logger.info("Task #{task.id}: complete, marking as reminded")
      task.reminded = Time.now.utc
      task.save
    end
  end
end
