module Kukupa::Route
  @@mine = {}

  def self.all_routes
    @@mine
  end

  def my
    @@mine[inspect.to_sym] ||= {
      :routes => []
    }
  end

  def my=(r)
    @@mine[inspect.to_sym] = r
  end

  def add_route(verb, path, opts = {})
    verb = verb.to_s.upcase
    meth = opts[:method] ||= :index

    controller_entry = Kukupa::Controllers.active_controllers.select do |b|
      b[:controller] == inspect.split("::").last
    end.first

    # construct full path to method, removing trailing slash
    full_path = "#{controller_entry[:path]}#{path.sub(/\/$/, '')}"

    # specify verbs to add routes for. if verb is GET, also add a HEAD
    [verb, verb == "GET" ? "HEAD" : nil].compact.each do |v|
      my[:routes] << {
        :verb => v,
        :method => meth,
        :path => {
          :full => full_path,
          :fragment => path,
        }
      }

      # lets us refer to the controller class calling this in the below block
      this = self
      Kukupa::Application.class_eval do
        route(v, full_path, {}) do |*args|
          controller = this.new(self)
          controller.preflight()

          if controller.respond_to?(:before)
            controller.before(*args)
          end

          next controller.send(meth, *args)
        end
      end
    end
  end
end
