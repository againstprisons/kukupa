module Kukupa::Helpers
  # Load ApplicationHelpers first
  require File.join(Kukupa.root, 'app', 'helpers', 'application_helpers')

  # And then load the rest
  Dir.glob(File.join(Kukupa.root, 'app', 'helpers', '*.rb')).each do |f|
    require f
  end
end
