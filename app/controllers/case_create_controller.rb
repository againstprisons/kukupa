class Kukupa::Controllers::CaseCreateController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :post, '/'

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('case:create')

    @title = t(:'case/create/title')
    @user = current_user
  end

  def index
    if request.get?
      return haml(:'case/create', :locals => {
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

    @case = Kukupa::Models::Case.new(is_open: true).save
    @case.encrypt(:first_name, first_name)
    @case.encrypt(:middle_name, middle_name) if middle_name
    @case.encrypt(:last_name, last_name)
    @case.encrypt(:prisoner_number, prisoner_number)
    @case.save

    flash :success, t(:'case/create/success', case_id: @case.id)
    return redirect url("/case/#{@case.id}/view")
  end
end
