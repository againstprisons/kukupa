require 'sidekiq'
require 'sidekiq-scheduler'

module Kukupa::Workers
  Dir.glob(File.join(Kukupa.root, 'app', 'workers', '*.rb')).each do |f|
    require f
  end
end
