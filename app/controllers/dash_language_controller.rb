class Kukupa::Controllers::DashLanguageController < Kukupa::Controllers::ApplicationController
  add_route :post, "/"

  def index
    language = request.params['language']&.strip&.downcase
    unless Kukupa.languages.key?(language)
      flash :error, t(:'language/invalid')
      return redirect back
    end

    session[:lang] = language

    if logged_in?
      user = current_user
      user.encrypt(:preferred_language, language)
      user.save
    end

    redirect back
  end
end
