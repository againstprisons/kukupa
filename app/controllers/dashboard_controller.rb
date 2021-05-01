class Kukupa::Controllers::DashboardController < Kukupa::Controllers::ApplicationController
  add_route :get, "/"

  def index
    unless logged_in?
      session[:after_login] = "/dashboard"
      return redirect to "/auth"
    end

    @title = t(:'dashboard/title')

    @quick_links = Kukupa::Models::QuickLink.map do |ql|
      {
        id: ql.id,
        name: ql.decrypt(:name),
        url: ql.decrypt(:url),
        icon: ql.decrypt(:icon),
        sort_order: ql.sort_order || 0,
      }
    end.sort {|a, b| a[:sort_order] <=> b[:sort_order]}

    @user = current_user
    @user_name = @user.decrypt(:name)
    @user_name = nil if @user_name.nil? || @user_name&.empty?

    @my_tasks = Kukupa::Models::CaseTask.where(assigned_to: @user.id, completion: nil).map do |t|
      case_obj = Kukupa::Models::Case[t.case]
      view_url = Addressable::URI.parse(url("/case/#{case_obj.id}/view"))
      edit_url = Addressable::URI.parse(url("/case/#{case_obj.id}/task/#{t.id}"))
      content = Sanitize.fragment(t.decrypt(:content).to_s, Sanitize::Config::RESTRICTED)

      {
        case: case_obj,
        case_name: case_obj.get_name,
        case_type: case_obj.type,
        task: t,
        task_content: content,
        anchor: t.anchor,
        view_url: view_url,
        edit_url: edit_url,
      }
    end

    @my_cases = Kukupa::Models::Case.assigned_to(@user).map do |c|
      url = Addressable::URI.parse(url("/case/#{c.id}/view"))

      {
        :case => c,
        :name => c.get_name,
        :url => url.to_s,
      }
    end

    @my_cases_new_mail = @my_cases.map do |c|
      if c[:case].new_mail?
        c
      end
    end.compact

    if has_role?('case:spend:can_approve')
      @spends = Kukupa::Models::CaseSpend.where(approver: nil).map do |s|
        case_obj = Kukupa::Models::Case[s.case]
        next unless case_obj

        view_url = Addressable::URI.parse(url("/case/#{case_obj.id}/view"))
        edit_url = Addressable::URI.parse(url("/case/#{case_obj.id}/spend/#{s.id}"))
        approve_url = Addressable::URI.parse(url("/case/#{case_obj.id}/spend/#{s.id}/approve"))

        {
          case: case_obj,
          case_name: case_obj.get_name,
          spend: s,
          spend_amount: s.decrypt(:amount).to_f,
          spend_content: s.decrypt(:notes),
          anchor: s.anchor,
          edit_url: edit_url,
          view_url: view_url,
          approve_url: approve_url,
        }
      end
      
      @spends_incomplete = Kukupa::Models::CaseSpend.where(is_complete: false).exclude(approver: nil).map do |s|
        case_obj = Kukupa::Models::Case[s.case]
        next unless case_obj

        view_url = Addressable::URI.parse(url("/case/#{case_obj.id}/view"))
        edit_url = Addressable::URI.parse(url("/case/#{case_obj.id}/spend/#{s.id}"))

        {
          case: case_obj,
          case_name: case_obj.get_name,
          spend: s,
          spend_amount: s.decrypt(:amount).to_f,
          spend_content: s.decrypt(:notes),
          anchor: s.anchor,
          edit_url: edit_url,
          view_url: view_url,
        }
      end
    end

    if has_role?('case:correspondence:can_approve')
      @correspondence = Kukupa::Models::CaseCorrespondence.where(sent_by_us: true, approved: false).map do |cc|
        case_obj = Kukupa::Models::Case[cc.case]
        next unless case_obj

        view_url = Addressable::URI.parse(url("/case/#{case_obj.id}/view"))
        edit_url = Addressable::URI.parse(url("/case/#{case_obj.id}/correspondence/#{cc.id}"))
        approve_url = Addressable::URI.parse(url("/case/#{case_obj.id}/correspondence/#{cc.id}/approve"))

        {
          case: case_obj,
          case_name: case_obj.get_name,
          cc_obj: cc,
          cc_subject: cc.decrypt(:subject),
          anchor: cc.anchor,
          edit_url: edit_url,
          view_url: view_url,
          approve_url: approve_url,
        }
      end
    end

    return haml(:'dashboard/index', :locals => {
      title: @title,
      quick_links: @quick_links,
      user: {
        user: @user,
        name: @user_name,
      },
      cases_new_mail: @my_cases_new_mail,
      cases: @my_cases,
      tasks: @my_tasks,
      spends: @spends,
      spends_incomplete: @spends_incomplete,
      correspondence: @correspondence,
    })
  end
end
