class Kukupa::Controllers::SystemRolesController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/search', method: :search
  add_route :get, '/edit', method: :edit_redir
  add_route :get, '/edit/:uid', method: :edit
  add_route :post, '/edit/-/add', method: :edit_add
  add_route :post, '/edit/-/remove', method: :edit_remove

  include Kukupa::Helpers::SystemRolesHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:roles:access")
  end

  def index
    @title = t(:'system/roles/title')

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/index', layout: false, locals: {
        title: @title,
      })
    end
  end

  def search
    @title = t(:'system/roles/title')

    @type = request.params['type']&.strip&.downcase&.to_sym
    @type = :role if @type.nil? || @type&.empty?
    @value = request.params['value']&.strip&.downcase
    @value = nil if @value&.empty?

    # shortcut to all-users-with-roles if we're searching by role and no
    # search query was provided
    if @value.nil? && @type == :role
      @value = '*'
    end

    # if we don't have a query, spit out an error
    if @value.nil?
      flash :error, t(:'system/roles/search_results/errors/no_query')
      return redirect to('/system/roles')
    end

    @this_search_url = Addressable::URI.parse(url('/system/roles/search'))
    @this_search_url.query_values = {type: @type, value: @value}

    @users = []
    case @type
    when :role # search by role name, where '*' is all roles
      if @value == '*'
        user_roles = Kukupa::Models::UserRole.all
      else
        user_roles = Kukupa::Models::UserRole.where(role: @value).all
      end

      uids = user_roles.map(&:user_id).uniq
      @users = uids.map do |uid|
        Kukupa::Models::User[uid]
      end

    when :email # search by email
      @users = Kukupa::Models::User.where(email: @value).all

    when :uid # get user with the given id
      @users = [Kukupa::Models::User[@value.to_i]]
    end

    # retrieve roles for each user in our search results
    @users.map! do |user|
      {
        :user => user,
        :name => user.decrypt(:name),
        :roles => Kukupa::Models::UserRole.where(user_id: user.id).all,
      }
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/search_results', layout: false, locals: {
        title: @title,
        query_friendly: role_search_friendly(@type, @value),
        this_search_url: @this_search_url.to_s,
        users: @users,
      })
    end
  end

  def edit_redir
    uid = request.params['uid']&.strip.to_i
    if uid.positive?
      uri = Addressable::URI.parse(url("/system/roles/edit/#{uid}"))
      if request.params.key?('back')
        uri.query_values = {back: request.params['back']}
      end

      return redirect uri.to_s
    end

    redirect back
  end

  def edit(uid)
    @user = Kukupa::Models::User[uid.to_i]
    return halt 404 unless @user
    @roles = Kukupa::Models::UserRole.where(user_id: @user.id).all

    @title = t(:'system/roles/edit/title', name: @user.decrypt(:name), uid: @user.id)
    @query_back = request.params['back']&.strip
    @query_back = nil if @query_back&.empty?

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/edit', layout: false, locals: {
        title: @title,
        query_back: @query_back,
        user: @user,
        roles: @roles,
      })
    end
  end

  def edit_add
    @user = Kukupa::Models::User[request.params['uid']&.strip.to_i]
    return halt 404 unless @user

    back = Addressable::URI.parse(url("/system/roles/edit/#{@user.id}"))
    if request.params.key?('back')
      back.query_values = {back: request.params['back']}
    end

    unless @user.totp_enabled
      flash :error, t(:'system/roles/edit/add/errors/no_mfa')
      return redirect back.to_s
    end

    role = request.params['role']&.strip&.downcase
    if Kukupa::Models::UserRole.where(role: role, user_id: @user.id).count.positive?
      flash :error, t(:'system/roles/edit/add/errors/has_role', role: role)
      return redirect back.to_s
    end

    ur = Kukupa::Models::UserRole.new(role: role, user_id: @user.id)
    ur.save

    flash :success, t(:'system/roles/edit/add/success', role: role, ur: ur.id)
    redirect back.to_s
  end

  def edit_remove
    @user = Kukupa::Models::User[request.params['uid']&.strip.to_i]
    return halt 404 unless @user

    back = Addressable::URI.parse(url("/system/roles/edit/#{@user.id}"))
    if request.params.key?('back')
      back.query_values = {back: request.params['back']}
    end

    ur = Kukupa::Models::UserRole[request.params['rid']&.strip.to_i]
    if ur.nil? || ur&.user_id != @user.id
      flash :error, t(:'system/roles/edit/remove/errors/invalid_rid')
      return redirect back.to_s
    end

    ur.delete

    flash :success, t(:'system/roles/edit/remove/success', role: ur.role, ur: ur.id)
    redirect back.to_s
  end
end
