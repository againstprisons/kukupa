class Kukupa::Controllers::UserSettingsPrivacyAgreementController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def before(*args)
    unless Kukupa.app_config['privacy-agreement-enable']
      return halt redirect url('/')
    end

    @current_user = current_user
    @is_okay = @current_user.privacy_agreement_okay
  end

  def index
    @title = t(:'usersettings/privacy_agreement/title')

    if request.post?
      @current_user.privacy_agreement_okay = true
      @current_user.save

      flash :success, t(:'usersettings/privacy_agreement/success')
      return redirect url('/')
    end

    haml(:'usersettings/privacy_agreement', layout: :layout_minimal, locals: {
      title: @title,
      user: @current_user,
      is_okay: @is_okay,
      agreement: Kukupa.app_config['privacy-agreement-content'],
    })
  end
end
