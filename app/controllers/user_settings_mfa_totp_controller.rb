require 'rotp'
require 'rqrcode'
require 'base64'

class Kukupa::Controllers::UserSettingsMfaTotpController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/", method: :process

  include Kukupa::Helpers::MfaTotpHelpers

  def before(*args)
    return halt 404 unless logged_in?

    @title = t(:'usersettings/mfa/totp/title')
    @user = current_user
    @user_mfa = @user.mfa_data

    @secret = session[:totp_secret] = (session[:totp_secret] || ROTP::Base32.random_base32)
    @totp = rotp_instance(@secret)
  end

  def index
    @totp_qr = generate_qr(@totp.provisioning_uri(@user.email))

    haml :'usersettings/mfa/totp', layout: :layout_minimal, locals: {
      title: @title,
      user: @user,
      mfa: @user_mfa,
      totp: {
        secret: @secret,
        qrcode: @totp_qr,
      },
    }
  end

  def process
    @code = request.params['code']&.strip&.downcase
    @code = nil if @code&.empty?

    if @code.nil? || !@totp.verify(@code, drift_behind: 15)
      flash :error, t(:'usersettings/mfa/totp/errors/invalid_code')
      return redirect request.path
    end

    # if we get here, verification code was valid! let's store the secret.
    @user.encrypt(:totp_secret, @secret)
    @user.totp_enabled = true
    @user.save

    # remove secret from session
    session.delete(:totp_secret)

    # invalidate all of the user's session tokens except the current one
    @user.invalidate_tokens_except!(session[:token])

    # and we're done!
    flash :success, t(:'usersettings/mfa/totp/success')
    redirect url('/user/mfa')
  end
end
