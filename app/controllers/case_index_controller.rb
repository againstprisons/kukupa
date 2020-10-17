require 'chronic'

class Kukupa::Controllers::CaseIndexController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers
  include Kukupa::Helpers::CaseIndexHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index
    @all_cases = case_index_get_cases(
      view_all: has_role?('case:view_all'),
    )

    @title = t(:'case/index/title')
    return haml(:'case/index', :locals => {
      title: @title,
      cases: @all_cases,
      stats: @stats,
    })
  end
end
