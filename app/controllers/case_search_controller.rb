class Kukupa::Controllers::CaseSearchController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  include Kukupa::Helpers::CaseHelpers

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index
    @type = request.params['type']&.strip&.downcase
    @query = request.params['query']&.strip
    @results = []

    if @type.nil? || @type&.empty? || @query.nil? || @query&.empty?
      return redirect url("/case")
    end

    if @type == 'prn'
      ids = Kukupa::Models::CaseFilter
        .perform_filter(:prisoner_number, @query)
        .map(&:case)
        .compact
        .uniq

      ids.each do |id|
        @results << Kukupa::Models::Case[id]
      end

    elsif @type == 'name'
      ids = Kukupa::Models::CaseFilter
        .perform_filter(:name, @query)
        .map(&:case)
        .compact
        .uniq

      ids.each do |id|
        @results << Kukupa::Models::Case[id]
      end
    end

    if @results.empty?
      flash :warning, t(:'case/search/errors/no_cases')
      return redirect url("/case")
    end

    @results.map! do |c|
      name = c.get_name
      pseudonym = c.decrypt(:pseudonym)
      pseudonym = nil if pseudonym&.empty?
      prn = c.decrypt(:prisoner_number)
      prn = nil if prn&.empty?
      prison = Kukupa::Models::Prison[c.decrypt(:prison).to_i]
      if prison
        prison = {
          obj: prison,
          name: prison.decrypt(:name),
        }
      end

      {
        case_obj: c,
        url: url("/case/#{c.id}/view"),
        name: name,
        pseudonym: pseudonym,
        prn: prn,
        prison: prison,
      }
    end

    @title = t(:'case/search/title')
    return haml(:'case/search', :locals => {
      title: @title,
      query: t("case/search/res/#{@type}".to_sym, query: @query),
      results: @results,
    })
  end
end
