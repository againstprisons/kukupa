require 'chronic'

class Kukupa::Controllers::UserInfoViewController < Kukupa::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/-/admin-notes', method: :admin_notes

  def before(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('userinfo:access')
    
    @user = Kukupa::Models::User[uid.to_i]
    return halt 404 unless @user
  end

  def index(uid)
    @user_name = @user.decrypt(:name)
    @title = t(:'userinfo/view/title', name: @user_name)
    
    @user_cases = Kukupa::Models::CaseAssignedAdvocate.where(user: @user.id).map do |caa|
      case_obj = Kukupa::Models::Case[caa.case]
      
      {
        obj: case_obj,
        type: case_obj.type,
        name: case_obj.get_name,
        pseudonym: case_obj.get_pseudonym,
        purposes: case_obj.get_purposes,
      }
    end
  
    @user_tasks = Kukupa::Models::CaseTask.where(assigned_to: @user.id, completion: nil).map do |ct|
      case_obj = Kukupa::Models::Case[ct.case]

      {
        obj: ct,
        content: ct.decrypt(:content),
        case: {
          obj: case_obj,
          type: case_obj.type,
          name: case_obj.get_name,
        }
      }
    end

    return haml(:'userinfo/view', :locals => {
      title: @title,
      user: {
        obj: @user,
        name: @user_name,
        tags: @user.roles.map{|r| /tag\:(\w+)/.match(r)&.[](1)}.compact.uniq,
        notes: @user.decrypt(:admin_notes),
        cases: @user_cases,
        tasks: @user_tasks,
      },
    })
  end
  
  def admin_notes(uid)
    @notes = request.params['notes']&.strip
    @notes = nil if @notes&.empty?
    
    @user.encrypt(:admin_notes, @notes)
    @user.save
    
    flash :success, t(:'userinfo/view/admin_notes/success')
    redirect url("/uinfo/#{@user.id}")
  end
end
