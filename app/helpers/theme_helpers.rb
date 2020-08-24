module Kukupa::Helpers::ThemeHelpers
  def find_template(views, name, engine, &block)
    folder = nil
    if views.instance_of? Hash
      _, folder = views.detect do |k, v|
        engine == Tilt[k]
      end

      folder ||= views[:default]
    else
      folder = views
    end

    begin
      raise "no theme dir" unless Kukupa.theme_dir
      theme_folder = Pathname.new(folder).each_filename.to_a
      theme_folder.shift if theme_folder.first == "app"
      theme_folder = File.join(Kukupa.theme_dir, *theme_folder)

      found = false
      Tilt.default_mapping.extensions_for(engine).each do |extension|
        fn = "#{name}.#{extension}"
        if File.file?(File.join(theme_folder, fn))
          found = fn
        end
      end

      raise "template not in theme dir" unless found
      super(theme_folder, name, engine, &block)

    rescue => e
      folder = File.join(Kukupa.root, folder)
      super(folder, name, engine, &block)
    end
  end
end
