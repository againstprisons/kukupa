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
    @sort = request.params['sort']&.strip&.downcase
    @sort = 'assigned' if @sort.nil? || @sort&.empty?
    @sort = @sort.to_sym

    @cases = case_list_get_cases(sort: @sort)

    @title = t(:'case/list/title')
    return haml(:'case/list', :locals => {
      cuser: @user,
      title: @title,
      sort: @sort,
      cases: @cases,
    })
  end
end
