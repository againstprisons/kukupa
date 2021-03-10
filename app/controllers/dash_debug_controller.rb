class Kukupa::Controllers::DashDebugController < Kukupa::Controllers::ApplicationController
  add_route :get, "/restart", method: :restart
  add_route :get, "/lang-reload", method: :lang_reload

  def before(*args)
    return halt 404 unless settings.development?
  end

  def restart
    Kukupa::ServerUtils.app_server_restart!

    flash :success, "Issued server restart request."
    redirect back
  end

  def lang_reload
    Kukupa.load_languages

    flash :success, "Reloaded languages."
    redirect back
  end
end
