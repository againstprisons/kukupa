require 'addressable'

class Kukupa::Controllers::AuthSsoMagentaController < Kukupa::Controllers::ApplicationController
  include Kukupa::Helpers::AuthProviderHelpers

  add_route :get, "/:clientid"
  add_route :get, "/:clientid/callback", method: :callback

  def before(*args)
    return redirect url("/") if logged_in?
    @providers = auth_providers(filter_type: :magenta)
    return halt 404 unless @providers.count.positive?
  end

  def index(clientid)
    @provider = @providers[clientid]
    return halt 404 unless @provider

    @request = @provider.request
    session[:magenta_nonce] = @request.nonce

    redir_url = ::Addressable::URI.parse(@provider.base_url)
    redir_url.query_values = @request.query_params

    return redirect redir_url.to_s
  end

  def callback(clientid)
    @provider = @providers[clientid]
    return halt 404 unless @provider

    # get our response payload and signature
    payload = request.params['payload']&.strip
    payload = nil if payload&.empty?
    signature = request.params['signature']&.strip
    signature = nil if signature&.empty?
    if payload.nil? || signature.nil?
      return haml(:'auth/sso/errors/generic', locals: {
        title: t(:'auth/sso/errors/generic/title'),
        provider: @provider,
      })
    end

    # and verify the response
    @response = @provider.verify_response(payload, signature)
    unless @response && @response.nonce == session.delete(:magenta_nonce)
      return haml(:'auth/sso/errors/generic', locals: {
        title: t(:'auth/sso/errors/generic/title'),
        provider: @provider,
      })
    end

    # get the user object for the SSO method/external ID, if one exists
    @user = Kukupa::Models::User.where(
      sso_method: "magenta:#{@provider.name}",
      sso_external_id: @response.external_id.to_s,
    ).first

    # if a user doesn't exist with the SSO params, check if there's a user
    # with the email address given in the response. if there isn't, create
    # one, with the SSO params added
    unless @user
      @user = Kukupa::Models::User.find_or_create(
        email: @response.email_address,
      ) do |u|
        u.sso_method = "magenta:#{@provider.name}"
        u.sso_external_id = @response.external_id.to_s
        u.password_hash = nil
      end
    end

    # if the user has no SSO method set, this is a convert user
    if @user.sso_method.nil?
      # invalidate all session tokens
      @user.invalidate_tokens!

      # save the SSO method and external ID
      @user.sso_method = "magenta:#{@provider.name}"
      @user.sso_external_id = @response.external_id.to_s

      # disable non-SSO log in
      @user.password_hash = nil

      # and tell the user we're converting their account to SSO-only
      flash :success, t(:'auth/sso/converted_to_sso', provider: @provider.friendly_name)

    # if the user has a registered SSO provider that is not this provider,
    # we've gotta bail, and tell the user that they tried to log in with
    # the wrong SSO provider
    elsif @user.sso_method != "magenta:#{@provider.name}"
      return haml(:'auth/sso/errors/wrong_provider', locals: {
        title: t(:'auth/sso/errors/wrong_provider/title'),
      })
    end

    # Update the email address on the user object to the one in the Magenta
    # response, since it might have changed (if we got our user object from
    # the SSO params rather than by email address)
    @user.email = @response.email_address

    # Update the user's name from the Magenta response
    @user.encrypt(:name, @response.profile_name&.compact&.join(' '))

    # and save the user object
    @user.save

    # if the user has MFA enabled, send them through the MFA flow as usual
    if @user.totp_enabled
      flash :success, t(:'auth/sso/success_mfa', provider: @provider.friendly_name)

      session[:twofactor_uid] = @user.id
      return redirect to("/auth/mfa/totp")
    end

    # if they don't have MFA enabled, log in!
    session[:token] = @user.login!().token
    flash :success, t(:'auth/sso/success', {
      provider: @provider.friendly_name,
      user_name: @user.decrypt(:name),
    })

    # redirect to the after_login url if one was in the session,
    # otherwise redirect to the dashboard
    next_url = session.delete(:after_login)&.strip
    next_url = url("/dashboard") if next_url.nil? || next_url&.empty?
    return redirect next_url
  end
end
 
