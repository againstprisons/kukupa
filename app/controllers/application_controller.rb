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

    @current_user = current_user
    if Kukupa.app_config['privacy-agreement-enable']
      if @current_user && @current_user.has_role?('case:assignable')
        unless @current_user.privacy_agreement_okay
          okay = false
          okay = true if current_prefix?('/auth') && !current?('/auth/signup')
          okay = true if current_prefix?('/static')
          okay = true if current?('/user/privacy-agreement')

          unless okay
            return halt redirect url("/user/privacy-agreement")
          end
        end
      end
    end
  end
end
