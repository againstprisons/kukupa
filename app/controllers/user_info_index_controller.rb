require 'chronic'

class Kukupa::Controllers::UserInfoIndexController < Kukupa::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/'

  def before(*args)
    return halt 404 unless logged_in?
    @user = current_user
    return halt 404 unless @user.has_role?('userinfo:access')
  end

  def index
    @title = t(:'userinfo/index/title')

    if request.post?
      user = Kukupa::Models::User[request.params['uid'].to_i]
      return redirect url("/uinfo/#{user.id}") if user
      flash :error, t(:'userinfo/index/errors/not_found')
    end

    return haml(:'userinfo/index', :locals => {
      cuser: @user,
      title: @title,
    })
  end
end
