class Kukupa::Controllers::UserSettingsMfaController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/disable", method: :disable
  add_route :post, "/disable", method: :disable

  def before(*args)
    return halt 404 unless logged_in?

    @title = t(:'usersettings/mfa/title')
    @user = current_user
    @user_mfa = @user.mfa_data
  end

  def index
    # Render `index_enabled` if MFA is enabled for the user
    return self.index_enabled if @user_mfa[:enabled]

    # Else, render `index`, which is the view prompting the user to enable MFA
    haml :'usersettings/layout', locals: {title: @title} do
      haml :'usersettings/mfa/index', layout: false, locals: {
        title: @title,
        user: @user,
      }
    end
  end

  def index_enabled
    haml :'usersettings/layout', locals: {title: @title} do
      haml :'usersettings/mfa/index_enabled', layout: false, locals: {
        title: @title,
        user: @user,
        mfa: @user_mfa,
      }
    end
  end

  def disable
    if @user_mfa[:has_roles]
      flash :error, t(:'usersettings/mfa/disable/errors/has_roles')
      return redirect url('/user/mfa')
    end

    if request.post?
      password = request.params['password']&.strip
      password = nil if password&.empty?
      if @user.password_correct?(password)
        # Disable TOTP
        @user.totp_enabled = false
        @user.totp_secret = nil

        # TODO: Destroy security key entries

        # Invalidate recovery codes
        Kukupa::Models::Token.where(
          user_id: @user.id,
          use: 'mfa_recovery',
          valid: true,
        ).update(valid: false)

        # Save user
        @user.save

        flash :success, t(:'usersettings/mfa/disable/success')
        return redirect url('/user/mfa')

      else
        flash :error, t(:'usersettings/mfa/disable/errors/password_incorrect')
      end
    end

    haml :'usersettings/mfa/disable', layout: :layout_minimal, locals: {
      title: @title,
      user: @user,
      mfa: @user_mfa,
    }
  end
end
