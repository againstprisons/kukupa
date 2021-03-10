class Kukupa::Controllers::SystemQuickLinksController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/create', method: :create
  add_route :post, '/create', method: :create
  add_route :get, '/edit/:qlid', method: :edit
  add_route :post, '/edit/:qlid', method: :edit
  add_route :post, '/edit/:qlid/delete', method: :delete

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:quick_links")
  end

  def index
    @title = t(:'system/quicklinks/title')
    @quick_links = Kukupa::Models::QuickLink.map do |ql|
      {
        id: ql.id,
        name: ql.decrypt(:name),
        url: ql.decrypt(:url),
        icon: ql.decrypt(:icon),
        sort_order: ql.sort_order || 0,
        edit_url: url("/system/quick-links/edit/#{ql.id}")
      }
    end.sort {|a, b| a[:sort_order] <=> b[:sort_order]}

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/quicklinks/index', layout: false, locals: {
        title: @title,
        quick_links: @quick_links,
      })
    end
  end

  def create
    @title = t(:'system/quicklinks/create/title')

    if request.post?
      @name = request.params['name']&.strip
      @name = nil if @name&.empty?
      @url = request.params['url']&.strip
      @url = nil if @url&.empty?
      @icon = request.params['icon']&.strip
      @icon = nil if @icon&.empty?
      @sort_order = request.params['sort_order'].to_i

      if @name.nil? || @url.nil?
        flash :error, t(:'required_not_provided')
        return redirect request.path
      end

      @ql = Kukupa::Models::QuickLink.new(sort_order: @sort_order).save
      @ql.encrypt(:name, @name)
      @ql.encrypt(:url, @url)
      @ql.encrypt(:icon, @icon)
      @ql.save

      flash :success, t(:'system/quicklinks/create/success')
      return redirect url("/system/quick-links")
    end

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/quicklinks/create', layout: false, locals: {
        title: @title,
      })
    end 
  end

  def edit(qlid)
    @ql = Kukupa::Models::QuickLink[qlid.to_i]
    return halt 404 unless @ql

    @title = t(:'system/quicklinks/edit/title', qlid: qlid)
    @name = @ql.decrypt(:name)
    @url = @ql.decrypt(:url)
    @icon = @ql.decrypt(:icon)
    @sort_order = @ql.sort_order

    if request.post?
      @name = request.params['name']&.strip
      @name = nil if @name&.empty?
      @url = request.params['url']&.strip
      @url = nil if @url&.empty?
      @icon = request.params['icon']&.strip
      @icon = nil if @icon&.empty?
      @sort_order = request.params['sort_order'].to_i

      if @name.nil? || @url.nil?
        flash :error, t(:'required_not_provided')
        return redirect request.path
      end

      @ql.encrypt(:name, @name)
      @ql.encrypt(:url, @url)
      @ql.encrypt(:icon, @icon)
      @ql.sort_order = @sort_order
      @ql.save

      flash :success, t(:'system/quicklinks/edit/success')
    end

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/quicklinks/edit', layout: false, locals: {
        title: @title,
        ql: {
          ql: @ql,
          id: @ql.id,
          name: @name,
          url: @url,
          icon: @icon,
          sort_order: @sort_order,
        },
      })
    end 
  end

  def delete(qlid)
    @ql = Kukupa::Models::QuickLink[qlid.to_i]
    return halt 404 unless @ql

    unless request.params['confirm']&.strip&.downcase == 'on'
      flash :error, t(:'required_not_provided')
      return redirect back
    end

    @ql.delete
    flash :success, t(:'system/quicklinks/edit/delete/success')

    return redirect url("/system/quick-links")
  end
end
