class Kukupa::Controllers::AuthLoginController < Kukupa::Controllers::ApplicationController
  include Kukupa::Helpers::AuthProviderHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index
    @next = request.params['next']&.strip
    @next = url("/") if @next.nil? || @next&.empty?
    return redirect url(@next) if logged_in?
    session[:after_login] = @next

    @title = t(:'auth/login/title')

    if request.get?
      return haml(:'auth/login/index', locals: {
        :title => @title,
        :sso_enabled => auth_providers_count.positive?,
      })
    end

    errs = [
      request.params["email"].nil?,
      request.params["email"]&.strip.empty?,
      request.params["password"].nil?,
      request.params["password"]&.empty?,
    ]

    if errs.any?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    email = request.params["email"].strip.downcase
    password = request.params["password"]

    # check if user exists with this email
    user = Kukupa::Models::User.where(email: email).first
    unless user
      flash :error, t(:'auth/login/errors/invalid')
      return redirect request.path
    end

    # check for SSO
    unless user.sso_method.nil?
      flash :error, t(:'auth/login/errors/must_use_sso')
      return redirect request.path 
    end

    # check password confirmation
    unless user.password_correct?(password)
      flash :error, t(:'auth/login/errors/invalid')
      return redirect request.path
    end

    if user.totp_enabled
      session[:twofactor_uid] = user.id
      return redirect to("/auth/mfa/totp")
    end

    # if we get here, user has successfully logged in
    token = user.login!
    session[:token] = token.token

    if user.preferred_language
      lang = user.decrypt(:preferred_language)
      session[:lang] = lang
    end

    user_name = user.decrypt(:name)
    user_name = nil if user_name.nil? || user_name&.empty?
    flash :success, t(:'auth/login/success', user_name: user_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
