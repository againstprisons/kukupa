class Kukupa::Controllers::SystemWorkerController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :post, '/'

  include Kukupa::Helpers::SystemWorkerHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:worker")
    @workers = available_workers()
  end

  def index
    @title = t(:'system/worker/title')

    if request.get?
      return haml(:'system/layout', locals: {title: @title}) do
        haml(:'system/worker', layout: false, locals: {
          title: @title,
          workers: @workers,
        })
      end
    end

    worker = @workers[request.params['worker']&.strip]
    unless worker
      flash :error, t(:'system/worker/errors/invalid_worker')
      return redirect request.path
    end

    begin
      data = JSON.parse(request.params['data']&.strip)
      raise "not an array" unless data.is_a?(Array)
    rescue => e
      flash :error, t(:'system/worker/errors/invalid_data')
      return redirect request.path
    end

    job_id = worker[:worker].perform_async(*data)
    flash :success, t(:'system/worker/success', worker: worker[:sym].to_s, job_id: job_id)

    redirect request.path
  end
end
