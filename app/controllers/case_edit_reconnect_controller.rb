class Kukupa::Controllers::CaseEditReconnectController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/sync', method: :sync
  add_route :post, '/unlink', method: :unlink
  add_route :post, '/link', method: :link
  add_route :get, '/manual-link', method: :manual_link
  add_route :post, '/manual-link', method: :manual_link

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::ReconnectHelpers

  def before(cid)
    super
    return halt 404 unless logged_in?

    @prisons = Kukupa::Models::Prison.get_prisons
    @assignable_users = case_assignable_users

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end

    @show = Kukupa::Models::Case::CASE_TYPES[@case.type.to_sym][:show]
    return halt 404 unless @show[:reconnect]
  end

  def index(cid)
    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id.to_i.positive?
    @case_name = @case.get_name
    @title = t(:'case/edit/reconnect/index/title', name: @case_name)

    return haml(:'case/edit/reconnect/index', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_prn: @case.decrypt(:prisoner_number),
      case_show: @show,
      case_reconnect: {
        id: @reconnect_id,
        data: @reconnect_data,
        name: @reconnect_data ? @reconnect_data['name']&.compact&.join(' ') : nil,
      },
    })
  end

  def sync(cid)
    @case.reconnect_last_sync = nil
    @case.save

    jid = Kukupa::Workers::SyncCaseFromReconnectWorker.perform_async(@case.id)
    flash :success, t(:'case/edit/reconnect/index/sync/success', jid: jid)

    return redirect url("/case/#{@case.id}/edit/rc")
  end

  def unlink(cid)
    if request.params['confirm'].to_i.positive?
      @case.reconnect_id = nil
      @case.save

      flash :success, t(:'case/edit/reconnect/index/unlink/success')
    end

    return redirect url("/case/#{@case.id}/edit/rc")
  end

  def link(cid)
    @prn = @case.decrypt(:prisoner_number)
    @reconnect_data = reconnect_penpal(prn: @prn)
    unless @reconnect_data
      flash :error, t(:'case/edit/reconnect/index/link/errors/no_reconnect_data')
      return redirect url("/case/#{@case.id}/edit/rc")
    end

    unless @reconnect_data['prn'].to_s.strip == @prn.to_s.strip
      flash :error, t(:'case/edit/reconnect/index/link/errors/reconnect_prn_mismatch', rc: @reconnect_data['id'].to_s, local: @prn.to_s)
      return redirect url("/case/#{@case.id}/edit/rc")
    end

    @case.reconnect_id = @reconnect_data['id'].to_i
    @case.save

    Kukupa::Workers::SyncCasePenpalFromReconnectWorker.perform_async(@case.id)

    flash :success, t(:'case/edit/reconnect/index/link/success')
    return redirect url("/case/#{@case.id}/edit/rc")
  end

  def manual_link(cid)
    if request.post?
      @penpal_id = request.params['cid']&.to_i
      @reconnect_data = reconnect_penpal(cid: @penpal_id)

      if @reconnect_data && @reconnect_data&.key?('id')
        @case.reconnect_id = @reconnect_data['id'].to_i
        @case.save

        Kukupa::Workers::SyncCasePenpalFromReconnectWorker.perform_async(@case.id)

        flash :success, t(:'case/edit/reconnect/index/manual_link/success')
        return redirect url("/case/#{@case.id}/edit/rc")

      else
        flash :error, t(:'case/edit/reconnect/index/manual_link/errors/no_reconnect_data')
      end
    end

    @case_name = @case.get_name
    @title = t(:'case/edit/reconnect/index/manual_link/title', name: @case_name)

    return haml(:'case/edit/reconnect/manual_link', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
    })
  end
end
