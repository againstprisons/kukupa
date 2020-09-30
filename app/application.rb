class Kukupa::Application < Sinatra::Base
  helpers Kukupa::Helpers::ApplicationHelpers

  set :environment, ENV["RACK_ENV"] ||= "production"
  set :default_encoding, "UTF-8"
  set :views, File.join('app', 'views')
  set :haml, :format => :html5, :default_encoding => "UTF-8"
  enable :sessions

  not_found do
    haml :'errors/not_found', :layout => :layout_minimal, :locals => {
      :title => t(:'errors/not_found/title'),
      :no_flash => true,
    }
  end

  error do
    haml :'errors/internal_server_error', :layout => :layout_minimal, :locals => {
      :title => t(:'errors/internal_server_error/title'),
      :no_flash => true,
    }
  end
end
