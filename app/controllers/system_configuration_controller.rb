class Kukupa::Controllers::SystemConfigurationController < Kukupa::Controllers::SystemController
  include Kukupa::Helpers::SystemConfigurationHelpers

  add_route :get, "/"
  add_route :get, "/-/new-key", :method => :new_key
  add_route :get, "/:key", :method => :key_edit
  add_route :post, "/:key", :method => :key_edit
  add_route :post, "/:key/delete", :method => :key_delete

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:config:access")
  end

  def index
    @title = t(:'system/config/title')
    @entries = config_keyvalue_entries
    @has_deprecated = @entries.keys.map{|k| Kukupa::APP_CONFIG_DEPRECATED_ENTRIES.key?(k)}.any?

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/config/index', layout: false, locals: {
        title: @title,
        entries: @entries,
        has_deprecated: @has_deprecated,
        can_edit: has_role?("system:config:edit"),
      })
    end
  end

  def new_key
    return redirect to("/system/config/#{request.params["key"]}")
  end

  def key_edit(key)
    return halt 404 unless has_role?("system:config:edit")

    key = key.strip.downcase
    @title = t(:'system/config/edit/title', :key => key)
    entry = Kukupa::Models::Config.where(:key => key).first

    value = entry ? entry.value : ''
    type =  entry ? entry.type : 'text'

    if request.get?
      return haml(:'system/layout', locals: {title: @title}) do
        haml(:'system/config/edit', layout: false, locals: {
          title: @title,
          key: key,
          is_new: entry.nil?,
          type: type,
          value: value,
          deprecated: Kukupa::APP_CONFIG_DEPRECATED_ENTRIES[key],
          delete_url: "/system/config/#{key}/delete",
        })
      end
    end

    type = request.params["type"]&.strip&.downcase
    unless %w[bool text number json].include?(type)
      flash :error, t(:'system/config/edit/errors/type_invalid')
      return redirect request.path
    end

    value = request.params["value"]&.strip
    if type == "bool"
      value = value.downcase

      unless %w[yes no].include?(value.downcase)
        flash :error, t(:'system/config/edit/errors/value_not_bool')
        return redirect request.path
      end
    end

    if entry.nil?
      entry = Kukupa::Models::Config.new(:key => key)
    end

    entry.type = type
    entry.value = value
    entry.save

    # push key name to the list of pending refreshes
    if Kukupa::APP_CONFIG_ENTRIES.key?(key) && !(%w[maintenance].include?(key))
      unless Kukupa.app_config_refresh_pending.include?(key)
        Kukupa.app_config_refresh_pending << key
        session[:we_changed_app_config] = true
      end
    end

    flash :success, t(:'system/config/edit/success', :key => key)
    redirect request.path
  end

  def key_delete(key)
    return halt 404 unless has_role?("system:config:edit")

    key = key.strip.downcase
    entry = Kukupa::Models::Config.where(:key => key).first

    unless entry
      flash :error, t(:'system/config/delete/errors/invalid_key')
      return redirect to("/system/config/#{key}")
    end

    unless request.params["confirm"]&.strip == key
      flash :error, t(:'system/config/delete/errors/no_confirm')
      return redirect to("/system/config/#{key}")
    end

    entry.delete

    # push key name to the list of pending refreshes
    if Kukupa::APP_CONFIG_ENTRIES.key?(key) && !(%w[maintenance].include?(key))
      unless Kukupa.app_config_refresh_pending.include?(key)
        Kukupa.app_config_refresh_pending << key
        session[:we_changed_app_config] = true
      end
    end

    flash :success, t(:'system/config/delete/success', key: key)
    return redirect to("/system/config")
  end
end
