class Kukupa::Controllers::UserSettingsController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/change-name", method: :change_name
  add_route :post, "/change-email", method: :change_email
  add_route :post, "/change-password", method: :change_password

  def before
    return halt 404 unless logged_in?
  end

  def index
    @title = t(:'usersettings/title')
    @user = current_user

    haml :'usersettings/layout', locals: {title: @title} do
      haml :'usersettings/index', locals: {
        title: @title,
        user: {
          user: @user,
          name: @user.decrypt(:name),
          email: @user.email,
        }
      }
    end
  end

  def change_name
    @user = current_user
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
    @user = current_user
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
    @user = current_user
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
end
