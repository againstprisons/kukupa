class Kukupa::Controllers::AuthLogoutController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return redirect "/auth" unless logged_in?

    token = current_token
    token.invalidate!
    session.delete(:token)

    flash :success, t(:'auth/logout/success')
    redirect to('/auth')
  end
end
