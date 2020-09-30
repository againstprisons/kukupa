class Kukupa::Controllers::ApplicationController
  extend Kukupa::Route

  def initialize(app)
    @app = app
  end

  def method_missing(meth, *args, &bk)
    @app.instance_eval do
      self.send(meth, *args, &bk)
    end
  end

  def preflight
    # Check if maintenance mode
    if is_maintenance? && !maintenance_path_allowed?
      return halt 503, maintenance_render
    end

    # Set and check CSRF
    csrf_set!
    unless request.safe? 
      unless csrf_ok?
        return halt 403, "CSRF failed"
      end
    end
  end
end
