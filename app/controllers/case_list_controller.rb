require 'chronic'

class Kukupa::Controllers::CaseListController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseListHelpers

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("case:list:cases")
    @user = current_user
  end

  def index
    @is_open = request.params['closed'].to_i.zero?
    @sort = request.params['sort']&.strip&.downcase
    @sort = 'assigned' if @sort.nil? || @sort&.empty?
    @sort = 'purpose' unless @is_open
    @sort = @sort.to_sym

    @cases = case_list_get_cases(sort: @sort, is_open: @is_open)

    @title = t(:'case/list/title')
    return haml(:'case/list', :locals => {
      cuser: @user,
      title: @title,
      is_open: @is_open,
      sort: @sort,
      cases: @cases,
    })
  end
end
