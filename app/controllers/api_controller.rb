class Kukupa::Controllers::ApiController
  extend Kukupa::Route
  include Kukupa::Helpers::ApiHelpers

  def initialize(app)
    @app = app
  end

  def method_missing(meth, *args, &bk)
    @app.instance_eval do
      self.send(meth, *args, &bk)
    end
  end

  def preflight
    content_type 'application/json'

    if is_maintenance?
      return halt 503, api_json({
        success: false,
        error: "#{Kukupa.site_name} is in maintenance mode",
      })
    end

    unless valid_api_token?
      return halt 401, api_json({
        success: false,
        error: 'Invalid API token',
      })
    end
  end
end
