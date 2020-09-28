class Kukupa::Controllers::SystemApiKeyController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :post, '/create', method: :create
  add_route :post, '/revoke', method: :revoke

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:apikey:access")
    @user = current_user
  end

  def index
    @title = t(:'system/apikey/title')
    @my_apikeys = Kukupa::Models::Token.where(user_id: @user.id, use: 'apikey').map do |k|
      {
        :id => k.id,
        :creation => k.created,
        :expiry => k.expiry,
        :valid => k.check_validity!,
        :name => k.decrypt(:extra_data),
      }
    end.sort { |a, b| b[:creation] <=> a[:creation] }
 
    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/apikey', layout: false, locals: {
        title: @title,
        my_apikeys: @my_apikeys,
      })
    end
  end

  def create
    return halt 404 unless has_role?("system:apikey:create")

    @name = request.params['name']&.strip
    @name = nil if @name&.empty?
    unless @name
      flash :error, t(:'required_field_missing')
      return redirect url("/system/apikey")
    end

    @expiry_v = request.params['expiry']&.strip
    @expiry_v = nil if @expiry_v&.empty?
    @expiry = Chronic.parse(@expiry_v)
    if @expiry.nil? && !@expiry_v.nil?
      flash :warning, t(:'system/apikey/create/warnings/invalid_expiry')
    end

    @token = Kukupa::Models::Token.generate_long
    @token.use = 'apikey'
    @token.expiry = @expiry
    @token.user_id = @user.id
    @token.save
    @token.encrypt(:extra_data, @name)
    @token.save

    flash :success, t(:'system/apikey/create/success', name: @name, token: @token.token)
    redirect url("/system/apikey")
  end

  def revoke
    tokenid = request.params['tokenid'].to_i
    @token = Kukupa::Models::Token[tokenid]

    unless @token && @token.user_id == @user.id
      flash :error, t(:'system/apikey/revoke/errors/invalid_id')
      return redirect url("/system/apikey")
    end

    @name = @token.decrypt(:extra_data)
    @token.invalidate!

    flash :success, t(:'system/apikey/revoke/success', name: @name)
    redirect url("/system/apikey")
  end
end
