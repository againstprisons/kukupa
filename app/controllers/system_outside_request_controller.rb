class Kukupa::Controllers::SystemOutsideRequestController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/form/:form_name', method: :form_edit
  add_route :post, '/form/:form_name/category/add', method: :category_add
  add_route :post, '/form/:form_name/category/delete', method: :category_delete
  add_route :post, '/form/:form_name/agreement/add', method: :agreement_add
  add_route :post, '/form/:form_name/agreement/delete', method: :agreement_delete
  add_route :get, '/hide-prisons', method: :hide_prisons
  add_route :post, '/hide-prisons/add', method: :hide_prisons_add
  add_route :post, '/hide-prisons/delete', method: :hide_prisons_delete

  include Kukupa::Helpers::SystemOutsideRequestHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:outside_request")

    @hide_prisons = config_key_json('outside-request-hide-prisons').map do |pid|
      prison = Kukupa::Models::Prison[pid]

      {
        obj: prison,
        id: prison.id,
        name: prison.decrypt(:name),
        non_rc: prison.reconnect_id.nil?,
      }
    end

    @forms = config_key_json('outside-request-forms')
    @categories = config_key_json('outside-request-categories')
    @agreements = config_key_json('outside-request-required-agreements')
    @extra_metadata = config_key_json('outside-request-extra-metadata')
  end

  def index
    form = request.params['form']&.strip&.downcase
    form = 'default' if form.nil? || form&.empty?
    return redirect url("/system/outside-request/form/#{form}")
  end

  def form_edit(form_name)
    @title = t(:'system/outside_request/title')
    @prisons = Kukupa::Models::Prison
      .exclude(id: (@hide_prisons.map {|pr| pr[:id]}))
      .all
      .compact

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/outside_request/index', layout: false, locals: {
        title: @title,
        prisons: @prisons,
        hide_prisons: @hide_prisons,
        forms: @forms,
        this_form: form_name,
        categories: @categories,
        agreements: @agreements,
        extra_metadata: @extra_metadata,
      })
    end
  end

  def hide_prisons
    @title = t(:'system/outside_request/hide_prisons/title')
    @prisons = Kukupa::Models::Prison
      .exclude(id: (@hide_prisons.map {|pr| pr[:id]}))
      .all
      .compact

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/outside_request/hide_prisons', layout: false, locals: {
        title: @title,
        prisons: @prisons,
        hide_prisons: @hide_prisons,
      })
    end
  end

  def hide_prisons_add
    prison = Kukupa::Models::Prison[request.params['prison'].to_i]
    unless prison
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'outside-request-hide-prisons').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    data << prison.id
    entry.value = JSON.generate(data.uniq)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-hide-prisons'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/hide_prisons/add/success', name: prison.decrypt(:name))
    return redirect back
  end

  def hide_prisons_delete
    prison = Kukupa::Models::Prison[request.params['prison'].to_i]
    unless prison
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'outside-request-hide-prisons').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    data = data.reject {|x| x == prison.id}
    entry.value = JSON.generate(data.uniq)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-hide-prisons'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/hide_prisons/hidden/actions/delete/success', name: prison.decrypt(:name))
    return redirect back
  end

  def category_add(form_name)
    category = request.params['text']&.strip
    category = nil if category&.empty?
    if category.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'outside-request-categories').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    data[form_name] ||= []
    data[form_name] << category
    data[form_name] = data[form_name].uniq
    entry.value = JSON.generate(data)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-categories'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/categories/add/success', category: category)
    return redirect back
  end

  def category_delete(form_name)
    category = request.params['category']&.strip
    category = nil if category&.empty?
    if category.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end
    category = category.to_i

    entry = Kukupa::Models::Config.where(key: 'outside-request-categories').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    cat_name = data[form_name][category]
    data[form_name].delete_at(category)
    data[form_name] = data[form_name].uniq
    entry.value = JSON.generate(data)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-categories'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/categories/actions/delete/success', category: cat_name)
    return redirect back
  end

  def agreement_add(form_name)
    agreement = request.params['text']&.strip
    agreement = nil if agreement&.empty?
    if agreement.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'outside-request-required-agreements').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    data[form_name] ||= []
    data[form_name] << agreement
    data[form_name] = data[form_name].uniq
    entry.value = JSON.generate(data)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-required-agreements'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/agreements/add/success', agreement: agreement)
    return redirect back
  end

  def agreement_delete(form_name)
    agreement = request.params['agreement']&.strip
    agreement = nil if agreement&.empty?
    if agreement.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end
    agreement = agreement.to_i

    entry = Kukupa::Models::Config.where(key: 'outside-request-required-agreements').first
    return halt 500 unless entry
    data = JSON.parse(entry.value)
    agreement_name = data[form_name][agreement]
    data[form_name].delete_at(agreement)
    data[form_name] = data[form_name].uniq
    entry.value = JSON.generate(data)
    entry.save

    Kukupa.app_config_refresh_pending << 'outside-request-required-agreements'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/outside_request/agreements/actions/delete/success', agreement: agreement_name)
    return redirect back
  end
end
