class Kukupa::Controllers::UserSettingsController < Kukupa::Controllers::ApplicationController
  include Kukupa::Helpers::AuthProviderHelpers

  add_route :get, "/"
  add_route :post, "/change-name", method: :change_name
  add_route :post, "/change-email", method: :change_email
  add_route :post, "/change-password", method: :change_password
  add_route :post, "/change-case-load-limit", method: :change_case_load_limit

  def before
    return halt 404 unless logged_in?
    @user = current_user
    unless @user.sso_method.nil?
      ptype, pname = @user.sso_method&.split(':', 2)
      @user_sso_provider = auth_providers(filter_type: ptype.to_sym)
        .filter {|_, prv| prv.name == pname}
        .first
        .last
    end
  end

  def index
    @title = t(:'usersettings/title')

    haml :'usersettings/layout', locals: {title: @title} do
      haml :'usersettings/index', layout: false, locals: {
        title: @title,
        user: {
          user: @user,
          name: @user.decrypt(:name),
          email: @user.email,
          case_count: @user.case_count,
          case_load_limit: @user.case_load_limit,
          is_sso: !@user.sso_method.nil?(),
          sso_provider: @user_sso_provider,
          sso_identifier: [@user.sso_method, @user.sso_external_id].join("#"),
        }
      }
    end
  end

  def change_name
    unless @user.sso_method.nil?
      flash :error, t(:'usersettings/sso_provided/errors/cant_change')
      return redirect url("/user")
    end

    @name = request.params['name']&.strip
    @name = nil if @name&.empty?

    unless @name
      flash :error, t(:'required_field_missing')
      return redirect url("/user")
    end

    @user.encrypt(:name, @name)
    @user.save

    flash :success, t(:'usersettings/change_name/success', name: @name)
    redirect url("/user")
  end

  def change_email
    unless @user.sso_method.nil?
      flash :error, t(:'usersettings/sso_provided/errors/cant_change')
      return redirect url("/user")
    end

    @email = request.params['email']&.strip&.downcase
    @email = nil if @email&.empty?

    unless @email
      flash :error, t(:'required_field_missing')
      return redirect url("/user")
    end

    if Kukupa::Models::User.where(email: @email).count.positive?
      flash :error, t(:'usersettings/change_email/errors/email_exists')
      return redirect url("/user")
    end

    @user.email = @email
    @user.save

    flash :success, t(:'usersettings/change_email/success')
    redirect url("/user")
  end

  def change_password
    unless @user.sso_method.nil?
      flash :error, t(:'usersettings/sso_provided/errors/cant_change')
      return redirect url("/user")
    end

    unless @user.password_correct?(request.params['password'])
      flash :error, t(:'usersettings/change_password/errors/invalid_password')
      return redirect url("/user")
    end

    @newpass = request.params["newpass"]
    @newpass = nil if @newpass&.empty?
    @newconfirm = request.params["newpass_confirm"]
    @newconfirm = nil if @newconfirm&.empty?

    unless @newpass && @newconfirm
      flash :error, t(:'required_field_missing')
      return redirect url("/user")
    end

    unless @newpass == @newconfirm
      flash :error, t(:'usersettings/change_password/errors/passwords_dont_match')
      return redirect url("/user")
    end

    @user.password = @newpass
    @user.save

    flash :success, t(:'usersettings/change_password/success')
    redirect url("/user")
  end
  
  def change_case_load_limit
    @new_limit = request.params['limit'].to_i
    @new_limit = 0 if @new_limit < 0
    @user.case_load_limit = @new_limit
    @user.save
    
    flash :success, t(:'usersettings/case_load/success', limit: @new_limit == 0 ? '∞' : @new_limit.to_s)
    redirect url("/user")
  end
end
