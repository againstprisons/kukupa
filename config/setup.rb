ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

Encoding.default_external = "UTF-8"
Encoding.default_internal = "UTF-8"

require 'bundler/setup'
require 'dotenv/load'
require 'sinatra/base'
