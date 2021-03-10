class Kukupa::Controllers::SystemDashboardController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :post, '/act/invite', method: :invite
  add_route :post, '/act/test-email', method: :test_email

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")
    @user = current_user
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

  def test_email
    @email = Kukupa::Models::EmailQueue.new_from_template("test_email")
    @email.queue_status = 'queued'
    @email.encrypt(:recipients, JSON.generate({"mode": "list_uids", "uids": [@user.id]}))
    @email.encrypt(:subject, "Test email")
    @email.save

    flash :success, t(:'system/index/actions/test_email/success', qid: @email.id)
    redirect back
  end
end
