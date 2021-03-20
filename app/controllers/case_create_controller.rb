class Kukupa::Controllers::CaseCreateController < Kukupa::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/'
  add_route :get, '/project', method: :project
  add_route :post, '/project', method: :project

  include Kukupa::Helpers::CaseHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('case:create')

    @title = t(:'case/create/title')
    @user = current_user
  end

  def index
    if request.get?
      return haml(:'case/create/index', :locals => {
        title: @title,
      })
    end

    first_name = request.params['first_name']&.strip
    first_name = nil if first_name&.empty?
    middle_name = request.params['middle_name']&.strip
    middle_name = nil if middle_name&.empty?
    last_name = request.params['last_name']&.strip
    last_name = nil if last_name&.empty?
    prisoner_number = request.params['prisoner_number']&.strip
    prisoner_number = nil if prisoner_number&.empty?

    if first_name.nil? || last_name.nil? || prisoner_number.nil?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    # TODO: check for duplicate prisoner numbers
    # once we have case filters, strip out punctuation/spaces and do a filter
    # on the PRN field for our input, and redirect to the open case with that
    # PRN if one exists instead of creating a new case

    @case = Kukupa::Models::Case.new(type: 'case', is_open: true).save
    @case.email_identifier = Kukupa::Crypto.generate_token_short
    @case.encrypt(:first_name, first_name)
    @case.encrypt(:middle_name, middle_name) if middle_name
    @case.encrypt(:last_name, last_name)
    @case.encrypt(:prisoner_number, prisoner_number)
    @case.save

    Kukupa::Models::CaseFilter.create_filters_for(@case)

    flash :success, t(:'case/create/success', case_id: @case.id)
    return redirect url("/case/#{@case.id}/view")
  end

  def project
    if request.get?
      return haml(:'case/create/project', :locals => {
        title: @title,
      })
    end

    project_name = request.params['name']&.strip
    project_name = nil if project_name&.empty?
    is_private = request.params['private']&.strip&.downcase == 'on'

    if project_name.nil?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    @case = Kukupa::Models::Case.new(type: 'project', is_open: true, is_private: is_private).save
    @case.encrypt(:first_name, project_name)
    @case.save

    flash :success, t(:'case/create/project/success', case_id: @case.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
