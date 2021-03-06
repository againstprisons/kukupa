class Kukupa::Application < Sinatra::Base
  helpers Kukupa::Helpers::ApplicationHelpers

  set :environment, ENV["RACK_ENV"] ||= "production"
  set :default_encoding, "UTF-8"
  set :views, File.join('app', 'views')
  set :haml, :format => :html5, :default_encoding => "UTF-8"
  enable :sessions

  not_found do
    ctrl = Kukupa::Controllers::ErrorController.new(self)
    ctrl.preflight
    ctrl.before if ctrl.respond_to?(:before)

    ctrl.not_found
  end

  error do
    ctrl = Kukupa::Controllers::ErrorController.new(self)
    ctrl.preflight
    ctrl.before if ctrl.respond_to?(:before)

    ctrl.server_error
  end
end
