class Kukupa::Controllers::CaseEditReconnectController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/unlink', method: :unlink

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::ReconnectHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('case:reconnect')
    @user = current_user

    @prisons = Kukupa::Models::Prison.get_prisons
    @assignable_users = case_assignable_users
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @reconnect_id = @case.reconnect_id
    @reconnect_data = reconnect_penpal(cid: @reconnect_id) if @reconnect_id&.positive?
    @case_name = @case.get_name
    @title = t(:'case/edit/reconnect/index/title', name: @case_name)

    return haml(:'case/edit/reconnect/index', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      case_reconnect: {
        id: @reconnect_id,
        data: @reconnect_data,
        name: @reconnect_data ? @reconnect_data['name']&.compact&.join(' ') : nil,
      },
    })
  end

  def unlink(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    if request.params['confirm'].to_i.positive?
      @case.reconnect_id = nil
      @case.save

      flash :success, t(:'case/edit/reconnect/index/unlink/success')
    end

    return redirect url("/case/#{@case.id}/edit/rc")
  end
end
