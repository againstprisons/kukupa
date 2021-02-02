class Kukupa::Controllers::UserSettingsController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/change-name", method: :change_name
  add_route :post, "/change-email", method: :change_email
  add_route :post, "/change-password", method: :change_password
  add_route :post, "/change-case-load-limit", method: :change_case_load_limit

  def before
    return halt 404 unless logged_in?
    @user = current_user
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
        }
      }
    end
  end

  def change_name
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
