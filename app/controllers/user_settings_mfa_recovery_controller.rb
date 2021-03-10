class Kukupa::Controllers::UserSettingsMfaRecoveryController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/", method: :generate

  include Kukupa::Helpers::MfaTotpHelpers

  def before(*args)
    return halt 404 unless logged_in?

    @title = t(:'usersettings/mfa/recovery/title')
    @user = current_user
    @user_mfa = @user.mfa_data
  end

  def index
    haml :'usersettings/layout', locals: {title: @title} do
      haml :'usersettings/mfa/recovery', layout: false, locals: {
        title: @title,
        user: @user,
        mfa: @user_mfa,
      }
    end
  end

  def generate
    @title = t(:'usersettings/mfa/recovery/view/title')

    # Invalidate all previous recovery codes
    Kukupa::Models::Token.where(
      user_id: @user.id,
      use: 'mfa_recovery',
      valid: true,
    ).update(valid: false)

    # Generate new recovery codes
    @codes = 8.times.map do
      token = Kukupa::Models::Token.generate_short
      token.use = 'mfa_recovery'
      token.user_id = @user.id
      token.save

      {
        token: token,
        display: token.token.split('').each_slice(4).map(&:join).join('-'),
      }
    end

    haml :'usersettings/mfa/recovery_view', layout: :layout_minimal, locals: {
      title: @title,
      user: @user,
      mfa: @user_mfa,
      codes: @codes,
    }
  end
end
