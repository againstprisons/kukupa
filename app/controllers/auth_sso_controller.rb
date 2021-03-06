class Kukupa::Controllers::AuthSsoController < Kukupa::Controllers::ApplicationController
  include Kukupa::Helpers::AuthProviderHelpers

  add_route :get, "/"

  def before
    @providers = auth_providers()
    return halt 404 unless @providers.count.positive?
  end

  def index
    @next = request.params['next']&.strip
    @next = url("/") if @next.nil? || @next&.empty?
    return redirect url(@next) if logged_in?
    session[:after_login] = @next

    if @providers.count == 1
      return redirect url(@providers.first.last.begin_url)
    end

    haml(:'auth/sso/index', locals: {
      title: t(:'auth/sso/title'),
      providers: @providers,
    })
  end
end
