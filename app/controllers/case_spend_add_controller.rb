require 'sanitize'

class Kukupa::Controllers::CaseSpendAddController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index(cid)
    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case
    unless has_role?('case:view_all')
      return halt 404 unless @case.assigned_advocate == @user.id
    end

    @case_name = @case.get_name
    @title = t(:'case/spend/add/title', name: @case_name)

    if request.get?
      return haml(:'case/spend/add', :locals => {
        title: @title,
        case_obj: @case,
        case_name: @case_name,
      })
    end

    # get amount
    @amount = request.params['amount']&.strip.to_f
    if @amount < Kukupa.app_config['fund-min-spend']
      flash :error, t(:'case/spend/add/errors/below_minimum', min: Kukupa.app_config['fund-min-spend'])
      return redirect request.path
    end

    # get content
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?
    unless @content
      flash :error, t(:'case/spend/add/errors/no_content')
      return redirect request.path
    end

    # run a sanitize pass
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)

    # create spend
    @spend = Kukupa::Models::CaseSpend.new(case: @case.id, author: @user.id).save
    @spend.encrypt(:amount, @amount.to_s)
    @spend.encrypt(:notes, @content)
    @spend.save

    # if <= auto-approve threshold AND aggregate for this year is below max:
    #   - set approver to self
    #   - regenerate aggregate for this case
    if @amount <= Kukupa.app_config['fund-max-auto-approve']
      aggregate = Kukupa::Models::CaseSpendAggregate.get_case_year_total(@case, DateTime.now)
      if aggregate <= Kukupa.app_config['fund-max-spend-per-case-year']
        @spend.approver = @user.id
        @spend.save

        Kukupa::Models::CaseSpendAggregate.create_aggregate_for_case(@case)

        flash :success, t(:'case/spend/add/success/auto_approve', threshold: Kukupa.app_config['fund-max-auto-approve'])
        redirect url("/case/#{@case.id}/view##{@spend.anchor}")
      end

    else
      # TODO: send "new spending request to be approved" email
    end

    # redirect back
    flash :success, t(:'case/spend/add/success')
    redirect url("/case/#{@case.id}/view##{@spend.anchor}")
  end
end