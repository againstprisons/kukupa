class Kukupa::Controllers::AuthSignupController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?
    if !request.params["next"].nil?
      session[:after_login] = request.params["next"]
    end

    @token = request.params['token']&.strip
    @token = nil if @token&.empty?
    @token = @token.split(' ').map{|x| x.split('-')}.flatten.compact.join('') if @token
    @has_token = !(@token.nil?())
    @token = Kukupa::Models::Token.where(token: @token, use: 'invite').first
    @this_url = Addressable::URI.parse(to("/auth/signup"))
    @this_url.query_values = {token: @token.token} if @token

    @title = t(:'auth/signup/title')

    if !@has_token || @token.nil?
      return haml(:'auth/signup/no_token', locals: {
        :title => @title,
        :token => @token,
        :has_token => @has_token,
        :this_url => @this_url.to_s,
      })
    end

    if request.get?
      return haml(:'auth/signup/index', locals: {
        :title => @title,
        :token => @token,
        :has_token => @has_token,
        :this_url => @this_url.to_s,
      })
    end

    errs = [
      request.params["name"].nil?(),
      request.params["name"]&.strip&.empty?(),
      request.params["email"].nil?(),
      request.params["email"]&.strip&.empty?(),
      request.params["password"].nil?(),
      request.params["password"]&.empty?(),
      request.params["password_confirm"].nil?(),
      request.params["password_confirm"]&.empty?(),
    ]

    if errs.any?
      flash :error, t(:required_field_missing)
      return redirect @this_url.to_s
    end

    user_name = request.params['name'].strip
    email = request.params["email"].strip.downcase
    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    # check if user exists with this email
    if Kukupa::Models::User.where(email: email).count.positive?
      flash :error, t(:'auth/signup/errors/email_exists')
      return redirect @this_url.to_s
    end

    # check password confirmation
    unless password == password_confirm
      flash :error, t(:'auth/signup/errors/passwords_dont_match')
      return redirect @this_url.to_s
    end

    # create the user
    @user = Kukupa::Models::User.new(email: email)
    @user.save
    @user.encrypt(:name, user_name)
    @user.password = password
    @user.save

    # invalidate the invite token
    @token.invalidate!

    # redirect to login
    flash :success, t(:'auth/signup/success')
    redirect to("/auth")
  end
end
