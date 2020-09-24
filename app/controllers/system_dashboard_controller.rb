class Kukupa::Controllers::SystemDashboardController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :post, '/act/invite', method: :invite

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")
  end

  def index
    @title = t(:'system/index/title')

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/index', layout: false, locals: {
        title: @title,
      })
    end
  end

  def invite
    return halt 404 unless has_role?('system:generate_invite')

    @token = Kukupa::Models::Token.generate_short
    @token.use = 'invite'
    @token.expiry = Chronic.parse(Kukupa.app_config['invite-expiry'])
    @token.save
    @token_display = @token.token.split('').each_slice(4).map(&:join).join('-')

    flash :success, t(:'system/index/actions/invite/success', invite: @token_display, expiry: @token.expiry)
    redirect back
  end
end
