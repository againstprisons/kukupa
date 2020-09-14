require 'dotenv/tasks'

require File.expand_path("../config/kukupa.rb", __FILE__)
Kukupa.initialize(
  no_load_models: true,
  no_load_configs: true,
  no_check_keyderiv: true,
)

task app_setup: :dotenv do
  Kukupa::Models.load_models
  Kukupa.load_config
  Kukupa.app_config_refresh(:force => true)
end

task console: :app_setup do
  require 'pry'

  ARGV.clear
  Pry.start
end

namespace :cfg do
  desc "Set default values for configuration keys that are not already set"
  task defaults: :app_setup do |t|
    Kukupa::APP_CONFIG_ENTRIES.each do |key, desc|
      cfg = Kukupa::Models::Config.find_or_create(:key => key) do |a|
        a.type = desc[:type].to_s

        a.value = desc[:default].to_s
        if desc[:type] == :bool && !desc[:default].is_a?(String)
          a.value = (desc[:default] ? 'yes' : 'no')
        end
      end

      # correct configuration entry types
      if cfg.type != desc[:type].to_s
        cfg.type = desc[:type].to_s
        cfg.save
      end
    end

    puts "\e[47m\e[1;35m==> Done setting configuration defaults. \e[0m"
  end

  desc "Find configuration key duplicates"
  task duplicates: :app_setup do |t|
    keys = {}
    Kukupa::Models::Config.all.each do |cfg|
      keys[cfg.key] ||= []
      keys[cfg.key] << [cfg.id, cfg.value]
    end

    keys.each do |key, values|
      if values.count > 1
        puts "Key #{key.inspect} has #{values.count} entries:"
        values.each do |v|
          puts "\tID #{v.first}: #{v.last.inspect}"
        end
      end
    end
  end
end

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] => :dotenv do |_t, args|
    require 'sequel/core'
    version = args[:version].to_i if args[:version]

    Sequel.extension :migration
    Sequel.connect(ENV['DATABASE_URL'], search_path: [ENV['DB_SCHEMA'] || 'public']) do |db|
      Sequel::Migrator.run(db, 'migrations', target: version)
    end

    puts "\e[47m\e[1;35m==> Done running migrations. \e[0m"
  end

  desc 'Rollback to the penultimate migration and migrate to latest again'
  task redo: :dotenv do |_t|
    require 'logger'
    require 'sequel/core'

    version = Dir['migrations/*.rb']
      .map { |name| name.split('/').last.split('_').first }
      .sort
      .last(2)
      .first
      .to_i

    Sequel.extension :migration
    Sequel.connect(ENV['DATABASE_URL'], search_path: [ENV['DB_SCHEMA'] || 'public']) do |db|
      puts "\e[47m\e[1;35m==> Undoing to #{version}. \e[0m"
      Sequel::Migrator.run(db, 'migrations', target: version)
      puts "\e[47m\e[1;35m==> Migrating to latest. \e[0m"
      Sequel::Migrator.run(db, 'migrations')
    end

    puts "\e[47m\e[1;35m==> Done running migrations. \e[0m"
  end
end
