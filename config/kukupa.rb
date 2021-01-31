require File.expand_path(File.join("..", "setup.rb"), __FILE__)

require 'sinatra/base'
require 'yaml'
require 'sequel'
require 'mail'
require 'haml'
require 'addressable'

module Kukupa
  @@root = File.expand_path(File.join("..", ".."), __FILE__)

  def self.root
    @@root
  end

  require File.join(@@root, 'app', 'version')
  require File.join(@@root, 'app', 'utils')
  require File.join(@@root, 'app', 'config')
  require File.join(@@root, 'app', 'server_utils')
  require File.join(@@root, 'app', 'workers')

  class << self
    attr_reader :app
    attr_accessor :database

    attr_accessor :site_dir, :theme_dir
    attr_accessor :app_config, :app_config_refresh_pending

    attr_accessor :default_language, :languages
  end

  def self.filter_strip_chars
    [
      " ",
      "\t",
      "\n",
      "(",
      ")",
      "[",
      "]",
      "{",
      "}",
      '"',
      "'",
      "#",
      /[\u0080-\u00ff]/, # all non-ASCII characters
    ]
  end

  def self.initialize(opts = {})
    # Set our environment if it's not already set
    ENV["APP_ENV"] = nil
    ENV["RACK_ENV"] ||= "production"

    # Encoding things
    Encoding.default_internal = Encoding::UTF_8
    Encoding.default_external = Encoding::UTF_8

    # Do an early environment check
    %w[KEYDERIV_URL KEYDERIV_SECRET DATABASE_URL SITE_DIR].each do |var|
      unless ENV.key?(var)
        raise "Required environment variable #{var} not present, dying."
      end
    end

    # Load crypto early for keyderiv check
    require File.join(Kukupa.root, 'app', 'crypto')

    # Check whether we can reach keyderiv before allowing the app to initialize
    unless opts[:no_check_keyderiv]
      begin
        Kukupa::Crypto.get_index_key "test", "test"
      rescue => e
        raise "Couldn't reach keyderiv, dying. (#{e.class.name}: #{e.message})"
      end
    end

    # load core modules
    require File.join(Kukupa.root, 'app', 'route')
    require File.join(Kukupa.root, 'app', 'controllers')
    require File.join(Kukupa.root, 'app', 'helpers')
    require File.join(Kukupa.root, 'app', 'models')

    # load the helpers
    Kukupa::Helpers.load_helpers

    # load the application
    require File.join(Kukupa.root, 'app', 'application')

    # and then load the controllers
    Kukupa::Controllers.load_controllers

    @database = Sequel.connect(ENV["DATABASE_URL"])
    @database.extension(:pagination)
    Kukupa::Models.load_models unless opts[:no_load_models]

    @app_config = {}
    @app_config_refresh_pending = []

    unless opts[:no_load_configs]
      # load config files (including site config)
      self.load_config

      # load config from database
      self.app_config_refresh(:force => true) unless opts[:no_load_models]
    end

    # language support
    @default_language = 'en'
    self.load_languages

    @app = Kukupa::Application.new
  end

  def self.load_languages
    @languages = Dir.glob(File.join(Kukupa.root, 'config', 'translations', '*.yml')).map do |e|
      name = /(\w+)\.yml$/.match(e)[1]
      strings = YAML.load_file(e)

      [name, strings]
    end.to_h

    # Allow themes to override translation keys
    if @theme_dir
      @languages.keys.each do |tlname|
        override_file = File.join(@theme_dir, 'translations', "#{tlname}.yml")
        if File.exists?(override_file)
          strings = YAML.load_file(override_file)
          next unless strings

          strings.each do |key, value|
            @languages[tlname][key] = value
          end
        end
      end
    end

    # Filter out languages that have their `:meta_description` set to nil or
    # an empty string
    @languages.reject! do |name, strings|
      strings[:meta_description].nil? || strings[:meta_description]&.empty?
    end

    # In development mode, add a "language" that has no translated text, which
    # when t() is called, will display the translation key rather than any text
    if ENV['RACK_ENV'] == 'development'
      @languages["translationkeys"] = {
        :meta_description => "DEBUG: Translation keys"
      }
    end
  end

  def self.load_config
    require File.join(Kukupa.root, 'config', 'default_config.rb')
    require File.join(Kukupa.root, 'config', 'environments', "#{ENV["RACK_ENV"]}.rb")

    self.site_load_config
  end

  def self.app_config_refresh(opts = {})
    output = []

    Kukupa::APP_CONFIG_ENTRIES.each do |key, desc|
      cfg = Kukupa::Models::Config.where(:key => key).first
      if cfg
        value = cfg.value
      else
        value = desc[:default]
        if desc[:type] == :bool
          value = (value ? 'yes' : 'no')
        end

        value = value.to_s
      end

      parsed = value
      warnings = []
      stop = false
      Kukupa::Config.parsers.each do |parser|
        next if stop

        if parser.accept?(key, desc[:type])
          out = parser.parse(parsed)
          warnings << out[:warning] if out[:warning]
          parsed = out[:data]

          if !opts[:dry]
            parser.process(parsed) if parser.respond_to?(:process)
          end

          stop = out[:stop_processing_here]
        end
      end

      if !opts[:dry]
        @app_config[key] = parsed
      end

      output << {:key => key, :warnings => warnings}
    end

    @app_config_refresh_pending.clear if !opts[:dry]
    output
  end

  def self.site_load_config
    site_dir = ENV["SITE_DIR"]
    return if site_dir.nil?
    return unless Dir.exist?(site_dir)

    @site_dir = site_dir

    if File.file?(File.join(@site_dir, "config.rb"))
      require File.join(@site_dir, "config.rb")
    end
  end

  def self.site_load_theme(theme_dir)
    return false unless Dir.exist?(theme_dir)
    @theme_dir = theme_dir
  end
end
