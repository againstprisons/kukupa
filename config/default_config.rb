require 'securerandom'

module Kukupa
  APP_CONFIG_ENTRIES = {
    "site-name" => {
      :type => :text,
      :default => "Kūkupa",
    },
    "org-name" => {
      :type => :text,
      :default => "Example Organisation",
    },
    "base-url" => {
      :type => :text,
      :default => "https://localhost",
    },
    "display-version" => {
      :type => :bool,
      :default => false,
    },
    "email-from" => {
      :type => :text,
      :default => 'advocacy@example.com',
    },
    "email-smtp-host" => {
      :type => :text,
      :default => 'logger',
    },
    "email-subject-prefix" => {
      :type => :text,
      :default => 'site-name-brackets',
    },
    "header-logo-url" => {
      :type => :text,
      :default => '',
    },
    "invite-expiry" => {
      :type => :time_period,
      :default => 'in 72 hours',
    },
    "fund-min-spend" => {
      :type => :number,
      :default => 0,
    },
    "fund-max-auto-approve" => {
      :type => :number,
      :default => 0,
    },
    "fund-max-spend-per-case-year" => {
      :type => :number,
      :default => 100,
    },
    "task-overdue-notify" => {
      :type => :time_period,
      :default => '1 month ago',
    },
  }

  APP_CONFIG_DEPRECATED_ENTRIES = {
  }

  class Application
    configure do
      set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
    end
  end
end
