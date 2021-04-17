class Kukupa::Controllers::SystemMailTemplatesController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/create', method: :create
  add_route :post, '/create', method: :create
  add_route :get, '/edit/:tplid', method: :edit
  add_route :post, '/edit/:tplid', method: :edit
  add_route :get, '/groups', method: :group_list
  add_route :post, '/groups/add', method: :group_add
  add_route :post, '/groups/remove', method: :group_remove

  include Kukupa::Helpers::SystemConfigurationAttributeHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mail_templates")

    @title = t(:'system/mail_templates/title')
    @groups = Kukupa.app_config['case-mail-template-groups']
  end

  def index
    @templates = Kukupa::Models::MailTemplate.template_list(nil)

    # get grouped enabled
    @grouped_enabled = @groups.map{|x| [x, []]}.to_h
    @templates.filter{|tpl| tpl[:enabled]}.each do |tpl|
      if @grouped_enabled.key?(tpl[:group])
        @grouped_enabled[tpl[:group]] << tpl
      else
        @grouped_enabled[t(:'unknown')] ||= []
        @grouped_enabled[t(:'unknown')] << tpl
      end
    end

    # get grouped disabled
    @grouped_disabled = @groups.map{|x| [x, []]}.to_h
    @templates.reject{|tpl| tpl[:enabled]}.each do |tpl|
      if @grouped_disabled.key?(tpl[:group])
        @grouped_disabled[tpl[:group]] << tpl
      else
        @grouped_disabled[t(:'unknown')] ||= []
        @grouped_disabled[t(:'unknown')] << tpl
      end
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/mail_templates/index', layout: false, locals: {
        title: @title,
        templates_enabled: @grouped_enabled,
        templates_disabled: @grouped_disabled,
      })
    end
  end

  def create
    if request.post?
      @tpl_name = request.params['name']&.strip
      @tpl_name = nil if @tpl_name&.empty?
      unless @tpl_name
        flash :error, t(:'system/mail_templates/create/errors/no_name')
        return redirect request.path
      end

      @tpl_group = request.params['group'].to_i
      unless @tpl_group.negative?
        @tpl_group = @groups.index(@groups[@tpl_group])
      else
        @tpl_group = nil
      end

      @template = Kukupa::Models::MailTemplate.new(enabled: false).save
      @template.encrypt(:name, @tpl_name)
      @template.encrypt(:group, @tpl_group.nil?() ? nil : @groups[@tpl_group])
      @template.encrypt(:content, "<p>Replace this with your template content.</p>")
      @template.save

      flash :success, t(:'system/mail_templates/create/success')
      return redirect url("/system/mailtemplates/edit/#{@template.id}")
    end

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/mail_templates/create', layout: false, locals: {
        title: @title,
        groups: @groups,
      })
    end
  end
  
  def edit(tplid)
    @template = Kukupa::Models::MailTemplate[tplid.to_i]
    return halt 404 unless @template
    @template_name = @template.decrypt(:name)
    @template_content = @template.decrypt(:content)
    @tpl_group = @groups.index(@template.decrypt(:group))
    
    if request.post?
      @template_name = request.params['name']&.strip
      @template_name = nil if @template_name&.empty?
      @template_content = request.params['content']&.strip
      @template_content = "" unless @template_content
      @template_content = Sanitize.fragment(@template_content, Sanitize::Config::RELAXED).strip
      @template_content = nil if @template_content&.empty?
      
      @tpl_group = request.params['group'].to_i
      unless @tpl_group.negative?
        @tpl_group = @groups.index(@groups[@tpl_group])
      else
        @tpl_group = nil
      end

      enabled = request.params['enabled']&.strip&.downcase == 'on'

      if @template_name && @template_content
        @template.encrypt(:name, @template_name)
        @template.encrypt(:group, @tpl_group.nil?() ? nil : @groups[@tpl_group])
        @template.encrypt(:content, @template_content)
        @template.enabled = enabled
        @template.save
        
        flash :success, t(:'system/mail_templates/edit/data/success')
      else
        flash :error, t(:'required_field_missing')
      end
    end

    @title = t(:'system/mail_templates/edit/title', name: @template_name)
    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/mail_templates/edit', layout: false, locals: {
        title: @title,
        groups: @groups,
        template: @template,
        template_name: @template_name,
        template_group: @tpl_group,
        template_content: @template_content,
      })
    end
  end

  def group_list
    @title = t(:'system/mail_templates/groups/title')
    @groups = config_key_json('case-mail-template-groups')

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/mail_templates/groups', layout: false, locals: {
        title: @title,
        groups: @groups,
      })
    end
  end

  def group_add
    @groups = config_key_json('case-mail-template-groups')

    group = request.params['group']&.strip
    group = nil if group&.empty?
    if group.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    unless @groups.map(&:downcase).index(group.downcase).nil?
      flash :error, t(:'system/mail_templates/groups/add/errors/already_exists')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'case-mail-template-groups').first
    return halt 500 unless entry
    @groups << group
    entry.value = JSON.generate(@groups.uniq)
    entry.save

    Kukupa.app_config_refresh_pending << 'case-mail-template-groups'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/mail_templates/groups/add/success', group: group)
    return redirect back
  end

  def group_remove
    @groups = config_key_json('case-mail-template-groups')

    group = request.params['group']&.strip
    group = nil if group&.empty?
    if group.nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    if @groups.map(&:downcase).index(group.downcase).nil?
      flash :error, t(:'required_field_missing')
      return redirect back
    end

    entry = Kukupa::Models::Config.where(key: 'case-mail-template-groups').first
    return halt 500 unless entry
    @groups.delete(group)
    entry.value = JSON.generate(@groups.uniq)
    entry.save

    Kukupa.app_config_refresh_pending << 'case-mail-template-groups'
    session[:we_changed_app_config] = true

    flash :success, t(:'system/mail_templates/groups/list/actions/remove/success', group: group)
    return redirect back
  end
end
