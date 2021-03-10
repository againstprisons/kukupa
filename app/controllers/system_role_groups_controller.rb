class Kukupa::Controllers::SystemRoleGroupsController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :post, '/-/create', method: :create
  add_route :get, '/:rgid', method: :edit
  add_route :post, '/:rgid/-/role/add', method: :role_add
  add_route :post, '/:rgid/-/role/delete', method: :role_delete
  add_route :get, '/:rgid/-/user/add', method: :user_add
  add_route :post, '/:rgid/-/user/add', method: :user_add
  add_route :post, '/:rgid/-/user/delete', method: :user_delete

  include Kukupa::Helpers::SystemRolesHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:roles:access")
  end

  def index
    @title = t(:'system/roles/groups/title')
    @groups = Kukupa::Models::RoleGroup.map do |rg|
      users = rg.role_group_users.map do |rgu|
        {
          rgu: rgu.id,
          id: rgu.user.id,
          name: rgu.user.decrypt(:name),
        }
      end

      {
        id: rg.id,
        name: rg.name,
        users: users,
      }
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/groups/index', layout: false, locals: {
        title: @title,
        groups: @groups,
      })
    end
  end

  def create
    @name = request.params['name']&.strip
    @name = nil if @name&.empty?
    unless @name
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    @group = Kukupa::Models::RoleGroup.new(name: @name).save

    flash :success, t(:'system/roles/groups/create/success')
    return redirect url("/system/roles/groups/#{@group.id}")
  end

  def edit(rgid)
    @group = Kukupa::Models::RoleGroup[rgid.to_i]
    return halt 404 unless @group

    @title = t(:'system/roles/groups/edit/title', name: @group.name)
    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/groups/edit', layout: false, locals: {
        title: @title,
        group: @group,
        group_roles: @group.role_group_roles,
      })
    end
  end

  def role_add(rgid)
    @group = Kukupa::Models::RoleGroup[rgid.to_i]
    return halt 404 unless @group

    role = request.params['role']&.strip&.downcase
    if role.nil? || role&.empty?
      flash :error, t(:'required_field_missing')
      return redirect url("/system/roles/groups/#{@group.id}")
    end

    if @group.role_group_roles.map(&:role).include?(role)
      flash :error, t(:'system/roles/groups/edit/add/errors/has_role')
      return redirect url("/system/roles/groups/#{@group.id}")
    end

    @rgr = Kukupa::Models::RoleGroupRole.new(
      role_group_id: @group.id,
      role: role,
    ).save

    flash :success, t(:'system/roles/groups/edit/add/success', rgr: @rgr.id)
    return redirect url("/system/roles/groups/#{@group.id}")
  end

  def role_delete(rgid)
    @group = Kukupa::Models::RoleGroup[rgid.to_i]
    return halt 404 unless @group

    @rgr = Kukupa::Models::RoleGroupRole[request.params['rgr'].to_i]
    return halt 404 unless @rgr

    @rgr.delete

    flash :success, t(:'system/roles/groups/edit/existing/item/actions/remove/success', role: @rgr.role)
    return redirect url("/system/roles/groups/#{@group.id}")
  end

  def user_add(rgid)
    @group = Kukupa::Models::RoleGroup[rgid.to_i]
    return halt 404 unless @group

    if request.post?
      @user = Kukupa::Models::User[request.params['user'].to_i]
      unless @user
        flash :error, t(:'system/roles/groups/add_user/errors/invalid_user')
        return redirect request.path
      end

      if @group.role_group_users.map(&:user).map(&:id).include?(@user.id)
        flash :error, t(:'system/roles/groups/add_user/errors/user_in_group')
        return redirect request.path
      end

      if @group.requires_2fa
        unless @user.mfa_data[:enabled]
          flash :error, t(:'system/roles/groups/add_user/errors/user_no_mfa')
          return redirect request.path
        end
      end

      @rgu = Kukupa::Models::RoleGroupUser.new(
        role_group_id: @group.id,
        user_id: @user.id
      ).save

      flash :success, t(
        :'system/roles/groups/add_user/success',
        name: @user.decrypt(:name) || t(:'unknown'),
        rgu: @rgu.id
      )

      return redirect request.path
    end

    @title = t(:'system/roles/groups/add_user/title', name: @group.name)

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/roles/groups/add_user', layout: false, locals: {
        title: @title,
        group: @group,
      })
    end
  end

  def user_delete(rgid)
    @group = Kukupa::Models::RoleGroup[rgid.to_i]
    return halt 404 unless @group

    @rgu = Kukupa::Models::RoleGroupUser[request.params['rgu'].to_i]
    return halt 404 unless @rgu

    @rgu.delete

    flash :success, t(
      :'system/roles/groups/list/item/actions/remove_user/success',
      name: @rgu.user&.decrypt(:name) || t(:'unknown'),
      uid: @rgu.user&.id,
    )

    return redirect url("/system/roles/groups")
  end
end
