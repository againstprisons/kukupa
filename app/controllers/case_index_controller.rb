class Kukupa::Controllers::CaseIndexController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  def before
    return halt 404 unless logged_in?
    @user = current_user
  end

  def index
    @all_cases = Kukupa::Models::Case.map do |c|
      url = Addressable::URI.parse(url("/case/view/#{c.id}"))
      advocate = Kukupa::Models::User[c.assigned_advocate]

      {
        :case => c,
        :name => c.get_name,
        :url => url.to_s,
        :advocate => advocate,
        :advocate_name => advocate&.decrypt(:name),
        :mine => c.assigned_advocate == @user.id,
      }
    end

    @all_cases.sort! { |a, b| a[:mine] <=> b[:mine] }

    # only let admins see all cases by rejecting anything that isn't :mine
    unless has_role?('case:view_all')
      @all_cases.reject! { |x| !x[:mine] }
    end

    @title = t(:'case/index/title')
    return haml(:'case/index', :locals => {
      title: @title,
      cases: @all_cases,
    })
  end
end
