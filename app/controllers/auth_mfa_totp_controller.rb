class Kukupa::Controllers::AuthMfaTotpController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?
    if !request.params["next"].nil?
      session[:after_login] = request.params["next"]
    end

    @title = t(:'auth/login/mfa/totp/title')

    # double check that the user actually exists
    user = Kukupa::Models::User[session[:twofactor_uid].to_i]
    unless user
      flash :error, t(:'auth/login/errors/invalid')
      return redirect url('/auth')
    end

    if request.get?
      return haml :'auth/login/mfa_totp', layout: :layout_minimal, locals: {
        title: @title,
      }
    end

    auth_ok = false

    # split and recombine the verification code
    @code = request.params['code']&.strip&.downcase
    @code = @code.split(' ').map{|x| x.split('-')}.flatten.join('')

    # if the given code is over 8 characters, treat it as a recovery code
    if @code.length > 8
      token = Kukupa::Models::Token.where(
        token: @code,
        use: 'mfa_recovery',
        user_id: user.id,
      ).first

      if token&.check_validity!
        auth_ok = true
        token.invalidate!
      end

    # otherwise, verify it as a totp code
    else
      if user.mfa_totp_instance.verify(@code, drift_behind: 15)
        auth_ok = true
      end
    end

    # if we didn't authenticate successfully, flash and redir back to self
    # to show the page again
    unless auth_ok
      flash :error, t(:'auth/login/mfa/totp/errors/invalid_code')
      return redirect request.path
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

    # Redirect to MFA settings if we're using a recovery code
    if @code.length > 8
      flash :success, t(:'auth/login/success_recovery', user_name: user_name)
      return redirect to('/user/mfa')
    end

    flash :success, t(:'auth/login/success', user_name: user_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
