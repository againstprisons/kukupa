module Kukupa::ServerUtils
  module_function

  # Returns which server software is running this application. Currently only
  # supports detecting Puma (`:puma`), will return `:unknown` for all other
  # servers.
  def app_server
    return :puma if defined?(Puma::Server) && !Puma::Server.current.nil?

    :unknown
  end

  # Returns a boolean signifying whether the server software is using multiple
  # workers to serve this application. Currently only supports Puma on Linux,
  # as it relies on `/proc`.
  def app_server_has_multiple_workers?
    if app_server == :puma
      if RUBY_PLATFORM =~ /linux/
        should_start_with = ['puma', Puma::Const::PUMA_VERSION].join(' ')
        parent_cmdline = File.read("/proc/#{Process.ppid}/cmdline")
        if parent_cmdline.start_with? should_start_with
          return true
        end
      end
    end

    false
  end

  # Restarts the application server software. Returns a boolean signifying
  # whether or not the restart was attempted. Currently only supports
  # restarting Puma.
  #
  # Restart behaviour for supported server software:
  #   Puma: starts a phased restart (signal USR1)
  def app_server_restart!
    if app_server == :puma
      to_signal = Process.pid
      to_signal = Process.ppid if app_server_has_multiple_workers?

      pid = Process.spawn(
        {
          "RESTART_PID" => to_signal.to_s,
        },

        RbConfig.ruby, "-e", "sleep 2; Process.kill('USR1', ENV['RESTART_PID'].to_i)",
        :unsetenv_others => true
      )

      Process.detach(pid)

      return true
    end

    false
  end
end
