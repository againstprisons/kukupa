class Kukupa::Controllers::AuthResetController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/:token", method: :reset
  add_route :post, "/:token", method: :reset

  def index
    @title = t(:'auth/reset_request/title')

    if request.get?
      return haml(:'auth/reset/index', locals: {
        title: @title,
      })
    end

    email_address = request.params['email']&.strip&.downcase
    user = Kukupa::Models::User.where(email: email_address).first
    unless user # Bail early if no user
      flash :success, t(:'auth/reset_request/success')
      return redirect request.path
    end

    # don't allow password resets for SSO accounts
    unless user.sso_method.nil?
      flash :success, t(:'auth/reset_request/success')
      return redirect request.path
    end

    # Generate the password reset token
    token = Kukupa::Models::Token.generate_long
    token.use = 'password_reset'
    token.user_id = user.id
    token.expiry = Chronic.parse("in 30 minutes")
    token.save

    # Send the email
    begin
      reset_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
      reset_url += "/auth/reset/#{token.token}"

      email = Kukupa::Models::EmailQueue.new_from_template("password_reset", {
        email: email_address,
        reset_url: reset_url.to_s,
      })

      email.queue_status = 'queued'
      email.encrypt(:subject, "Reset your password") # TODO: tl this
      email.encrypt(:recipients, JSON.generate({
        "mode": "list_uids",
        "uids": [user.id],
      }))

      email.save
    end

    # Flash success
    flash :success, t(:'auth/reset_request/success')
    return redirect request.path
  end

  def reset(token)
    @token = Kukupa::Models::Token.where(token: token).first
    return halt 404 unless @token
    @user = @token.user
    return halt 404 unless @user

    unless @token.check_validity!
      flash :warning, t(:'auth/reset/errors/token_expired')
      return redirect url("/auth/reset")
    end

    @title = t(:'auth/reset/title')
    if request.get?
      return haml(:'auth/reset/reset', locals: {
        title: @title,
      })
    end

    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    # check password confirmation
    unless password == password_confirm
      flash :error, t(:'auth/reset/errors/passwords_dont_match')
      return redirect request.path
    end

    # save new password
    @user.password = password
    @user.save

    # invalidate reset token
    @token.invalidate!

    # redirect to login page
    flash :success, t(:'auth/reset/success')
    return redirect url("/auth")
  end
end
