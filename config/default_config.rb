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
    "file-storage-dir" => {
      :type => :text,
      :default => '@SITEDIR@/files/',
    },
    "email-from" => {
      :type => :text,
      :default => 'advocacy@example.com',
    },
    "email-outgoing-reply-to" => {
      :type => :text,
      :default => 'advocacy+%IDENTIFIER%@example.com',
    },
    "email-smtp-host" => {
      :type => :text,
      :default => 'logger',
    },
    "email-imap-host" => {
      :type => :text,
      :default => 'none',
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
    "task-default-deadline" => {
      :type => :time_period,
      :default => 'in 1 week',
    },
    "reconnect-url" => {
      :type => :text,
      :default => '',
    },
    "reconnect-api-key" => {
      :type => :text,
      :default => '',
    },
    "reconnect-penpal-id" => {
      :type => :number,
      :default => 0,
    },
    "reconnect-sync-after" => {
      :type => :time_period,
      :default => '10 minutes ago',
    },
    "reconnect-create-penpals" => {
      :type => :bool,
      :default => false,
    },
    "case-new-threshold" => {
      :type => :time_period,
      :default => '5 days ago',
    },
    "case-default-summary" => {
      :type => :html,
      :default => '<p></p>',
    },
    "case-purposes" => {
      :type => :json,
      :default => '["advocacy", "ppc"]',
    },
    "case-mail-template-groups" => {
      :type => :json,
      :default => '[]',
    },
    "magenta-providers" => {
      :type => :json,
      :default => '[]',
    },
    "privacy-agreement-enable" => {
      :type => :bool,
      :default => false,
    },
    "privacy-agreement-content" => {
      :type => :html,
      :default => '<p>This is the default privacy agreement text.</p>',
    },
    "outside-request-hide-prisons" => {
      :type => :json,
      :default => '[]',
    },
    "outside-request-forms" => {
      :type => :json,
      :default => '{"default": {"title": "outside/request/title", "renderable": "outside/request/renderable_title"}}',
    },
    "outside-request-override-tl" => {
      :type => :json,
      :default => JSON.generate({
        :default => {
          :content => [
            :'outside/request/content/one',
          ],
          :extra_metadata => :'outside/request/extra_metadata/section_title',
          :categories => :'outside/request/categories/section_title',
          :details => :'outside/request/details/section_title',
          :details_field => :'outside/request/details/field_request',
          :agreements => :'outside/request/agreements/section_title',
        },
      }),
    },
    "outside-request-extra-metadata" => {
      :type => :json,
      :default => '{"default": []}',
    },
    "outside-request-required-agreements" => {
      :type => :json,
      :default => '{"default": []}',
    },
    "outside-request-categories" => {
      :type => :json,
      :default => '{"default": []}',
    },
    "outside-request-save-provided-prison" => {
      :type => :bool,
      :default => :true,
    },
    "outside-request-create-reconnect-penpal" => {
      :type => :bool,
      :default => true,
    },
    "timeline-upcoming-notify" => {
      :type => :time_period,
      :default => 'in 1 week',
    },
    "feature-case-correspondence-email" => {
      :type => :bool,
      :default => false,
    },
    "correspondence-print-only-prisoner" => {
      :type => :bool,
      :default => true,
    },
    "correspondence-print-users" => {
      :type => :uid_list,
      :default => '',
    },
  }

  APP_CONFIG_DEPRECATED_ENTRIES = {
    "prisons-hide-from-public" => {
      :in => "0.1.0-alpha.1",
      :reason => "Changed key name to 'outside-request-hide-prisons'",
    },
    "task-overdue-notify" => {
      :in => "0.1.0-alpha.1",
      :reason => (
        "Overdue tasks are now notified by the deadline on individual tasks, " \
        "rather than by 'time since creation' as a global setting."
      ),
    },
  }

  class Application
    configure do
      set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
    end
  end
end
