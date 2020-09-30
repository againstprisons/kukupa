module Kukupa::Helpers::SystemWorkerHelpers
  def available_workers
    Kukupa::Workers.constants.map do |sym|
      m = Kukupa::Workers.const_get(sym)
      next nil unless m.respond_to?(:perform_async)

      [
        sym.to_s,
        {
          :sym => sym,
          :worker => m,
        }
      ]
    end.compact.to_h
  end
end
