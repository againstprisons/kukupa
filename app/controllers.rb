module Kukupa::Controllers
  @@controllers_yml = YAML.load_file(File.join(Kukupa.root, 'config', 'controllers.yml'))
  @@preload_controllers = @@controllers_yml["preload"]
  @@active_controllers = @@controllers_yml["controllers"].map do |c|
    {
      :path => c["path"],
      :controller => c["controller"],
    }
  end

  def self.preload_controllers
    @@preload_controllers
  end

  def self.active_controllers
    @@active_controllers
  end

  def self.load_controllers
    # Load in the controllers specified as preload
    preload_controllers.each do |c|
      cname = Kukupa::Utils.camel_case_to_snake_case(c)
      require File.join(Kukupa.root, "app", "controllers", cname)
    end

    # Load in all the other controllers
    active_controllers.each do |c|
      cname = Kukupa::Utils.camel_case_to_snake_case(c[:controller])
      require File.join(Kukupa.root, "app", "controllers", cname)
    end
  end
end
