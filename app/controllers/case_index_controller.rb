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
    @title = t(:'case/index/title')
    @cases = case_index_get_cases()
    @projects = case_index_get_projects()

    return haml(:'case/index', :locals => {
      cuser: @user,
      title: @title,
      cases: @cases,
      projects: @projects,
      stats: @stats,
    })
  end
end
