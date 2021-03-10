class Kukupa::Controllers::SystemPrisonController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/sync', method: :sync_prisons
  add_route :get, '/:pid/edit', method: :edit
  add_route :post, '/:pid/edit', method: :edit

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:prison:access")
    @user = current_user
  end

  def index
    @title = t(:'system/prison/title')
    @prisons = Kukupa::Models::Prison.all.map do |pr|
      {
        obj: pr,
        id: pr.id,
        name: pr.decrypt(:name),
        reconnect_id: pr.reconnect_id,
      }
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/prison/index', layout: false, locals: {
        title: @title,
        prisons: @prisons,
      })
    end
  end

  def sync_prisons
    return halt 404 unless has_role?('system:prison:sync')

    jid = Kukupa::Workers::SyncPrisonsWorker.perform_async
    flash :success, t(:'system/prison/sync/success', jid: jid)
    redirect back
  end

  def edit(pid)
    return halt 404 unless has_role?('system:prison:edit')

    @prison = Kukupa::Models::Prison[pid.to_i]
    return halt 404 unless @prison

    if request.post?
      @bank_account = request.params['bank_account']&.strip&.downcase
      @bank_account = nil if @bank_account&.empty?

      if @prison.reconnect_id == nil
        @name = request.params['name']&.strip
        @name = nil if @name&.empty?
        @address = request.params['address']&.strip
        @address = nil if @address&.empty?
        @email = request.params['email']&.strip
        @email = nil if @email&.empty?

        if @name.nil? || @address.nil? || @email.nil?
          flash :error, t(:'required_field_missing')
          return redirect request.path
        end

        @prison.encrypt(:name, @name)
        @prison.encrypt(:physical_address, @address)
        @prison.encrypt(:email_address, @email)
      end

      @prison.encrypt(:bank_account, @bank_account)
      @prison.save

      flash :success, t(:'system/prison/edit/info/success')
    end

    @name = @prison.decrypt(:name)
    @address = @prison.decrypt(:physical_address)
    @address = @address&.split("\n")&.map(&:strip).join(", ")
    @email = @prison.decrypt(:email_address)
    @bank_account = @prison.decrypt(:bank_account)

    @title = t(:'system/prison/edit/title', name: @name)
    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/prison/edit', layout: false, locals: {
        title: @title,
        prison: @prison,
        editables: {
          name: @name,
          address: @address,
          email: @email,
          bank_account: @bank_account,
        },
      })
    end
  end
end
