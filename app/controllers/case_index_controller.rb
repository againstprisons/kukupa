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
    @cases = case_index_get_cases()
    @title = t(:'case/index/title')

    return haml(:'case/index', :locals => {
      cuser: @user,
      title: @title,
      cases: @cases,
      stats: @stats,
    })
  end
end
