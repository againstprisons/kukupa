module Kukupa::Helpers::EmailTemplateHelpers
  def new_tilt_template_from_fn(filename)
    path = File.join(Kukupa.root, "app", "views", "email_templates", filename)

    if Kukupa.theme_dir
      theme_path = File.join(Kukupa.theme_dir, "views", "email_templates", filename)
      if File.file?(theme_path)
        path = theme_path
      end
    end

    return nil unless File.file?(path)
    Tilt::ERBTemplate.new(path)
  end
end
