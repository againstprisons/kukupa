class Kukupa::Controllers::UserSettingsMfaController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"

  def before
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
end
