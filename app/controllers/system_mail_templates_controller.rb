class Kukupa::Controllers::SystemMailTemplatesController < Kukupa::Controllers::SystemController
  add_route :get, '/'
  add_route :get, '/create', method: :create
  add_route :post, '/create', method: :create
  add_route :get, '/edit/:tplid', method: :edit
  add_route :post, '/edit/:tplid', method: :edit

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
    @grouped_enabled [t(:'unknown')] = []
    @templates.filter{|tpl| tpl[:enabled]}.each do |tpl|
      if @grouped_enabled.key?(tpl[:group])
        @grouped_enabled[tpl[:group]] << tpl
      else
        @grouped_enabled[t(:'unknown')] << tpl
      end
    end

    # get grouped disabled
    @grouped_disabled = @groups.map{|x| [x, []]}.to_h
    @grouped_disabled [t(:'unknown')] = []
    @templates.reject{|tpl| tpl[:enabled]}.each do |tpl|
      if @grouped_disabled.key?(tpl[:group])
        @grouped_disabled[tpl[:group]] << tpl
      else
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
end
