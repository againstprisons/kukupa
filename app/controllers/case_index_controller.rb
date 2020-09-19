require 'chronic'

class Kukupa::Controllers::CaseIndexController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseIndexHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index
    @all_cases = case_index_get_cases(
      view_all: has_role?('case:view_all'),
    )

    # if we have 'case:stats:view' permission:
    #   - show total spending for last month
    #   - show total spending for this month
    if has_role?('case:stats:view')
      # TODO: don't use chronic here
      @last_month_spend = Kukupa::Models::CaseSpendAggregate.get_month_total(Chronic.parse('last month'))
      @this_month_spend = Kukupa::Models::CaseSpendAggregate.get_month_total(DateTime.now)

      @stats = {
        spend: {
          last: @last_month_spend,
          current: @this_month_spend,
        },
      }
    end

    @title = t(:'case/index/title')
    return haml(:'case/index', :locals => {
      title: @title,
      cases: @all_cases,
      stats: @stats,
    })
  end
end
