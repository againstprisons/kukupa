module Kukupa::Helpers::SystemDebugHelpers
  def debug_controller_list
    out = Kukupa::Route.all_routes.map do |ctrl, data|
      ctrl = ctrl.to_s.split('::').last

      path = Kukupa::Controllers.active_controllers
        .select { |x| x[:controller] == ctrl }
        .first[:path]

      routes = {}
      data[:routes].each do |r|
        routes[r[:path][:fragment]] ||= []
        routes[r[:path][:fragment]] << r[:verb]
      end

      {
        ctrl: ctrl,
        path: path,
        routes: routes,
      }
    end

    out.sort { |a, b| a[:ctrl] <=> b[:ctrl] }
  end
end
