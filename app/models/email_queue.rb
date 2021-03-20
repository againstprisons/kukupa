require 'tilt/erb'
require 'ostruct'

class Kukupa::Models::EmailQueue < Sequel::Model(:email_queue)
  EMAIL_CHUNK_SIZE = 25

  include Kukupa::Helpers::EmailTemplateHelpers

  class EmailData < Kukupa::Helpers::LanguageHelpers::LanguageData
    include Kukupa::Helpers::InEmailHelpers
  end

  def self.new_from_template(template, data = {})
    # TODO: allow setting language, check if template exists for given language
    # and default to Kukupa.default_language should the template not exist
    lang = "en"

    # add layout info to data hash
    data[:layout] ||= {}
    data[:layout][:text] ||= "layout.txt.erb"
    data[:layout][:html] ||= "layout.html.erb"
    data = EmailData.new(data)

    # create new EmailQueue instance
    entry = self.new(:queue_status => "preparing")
    entry.save # save to get an ID

    text_output = nil
    html_output = nil
    if template.nil?
      text_output = data[:content_text] if data[:content_text]
      html_output = data[:content_html] if data[:content_html]
    else
      # get templates
      text_template = entry.new_tilt_template_from_fn(File.join(lang, "#{template}.txt.erb"))
      html_template = entry.new_tilt_template_from_fn(File.join(lang, "#{template}.html.erb"))

      # render templates
      text_output = text_template.render(data) if text_template
      html_output = html_template.render(data) if html_template
    end

    # get themeable wrapper templates
    text_wrapper = entry.new_tilt_template_from_fn(data.layout[:text])
    html_wrapper = entry.new_tilt_template_from_fn(data.layout[:html])

    # render wrappers, passing in rendered output from above
    text_output = text_wrapper.render(data) { text_output.force_encoding('UTF-8') } if text_wrapper
    html_output = html_wrapper.render(data) { html_output.force_encoding('UTF-8') } if html_wrapper

    # save data on EmailQueue instance created earlier
    entry.encrypt(:content_text, text_output.force_encoding('UTF-8')) if text_output
    entry.encrypt(:content_html, html_output.force_encoding('UTF-8')) if html_output

    entry
  end

  def self.annotate_subject_prefix
    case Kukupa.app_config["email-subject-prefix"]
    when "none"
      ""
    when "org-name"
      "#{Kukupa.app_config["org-name"]}: "
    when "org-name-brackets"
      "[#{Kukupa.app_config["org-name"]}] "
    when "site-name"
      "#{Kukupa.app_config["site-name"]}: "
    else # site-name-brackets
      "[#{Kukupa.app_config["site-name"]}] "
    end
  end

  def self.annotate_subject(text)
    "#{self.annotate_subject_prefix}#{text}"
  end

  def self.recipients_list(data)
    mode = data["mode"]&.strip&.downcase
    if mode == "all"
      return Kukupa::Models::User.all&.map(&:email).compact

    elsif mode == "list"
      return data["list"]

    elsif mode == "list_uids"
      return data["uids"].uniq.map do |uid|
        Kukupa::Models::User[uid.to_i]&.email
      end.compact

    elsif mode == "roles"
      roles = data["roles"].map(&:strip).map(&:downcase)
      uids = []

      roles.each do |role|
        Kukupa::Models::UserRole.where(:role => role).all.each do |ur|
          uids << ur.user_id
        end
      end

      return uids.uniq.map do |uid|
        Kukupa::Models::User[uid]&.email
      end.compact
    end

    []
  end

  def generate_recipients_list
    return [] if self.recipients.nil?

    data = JSON.parse(self.decrypt(:recipients))
    self.class.recipients_list(data)
  end

  def generate_messages_chunked
    out = []

    chunks = self.generate_recipients_list.each_slice(EMAIL_CHUNK_SIZE).to_a
    chunks.each do |chunk|
      m = self.generate_message_no_recipients
      m.bcc = chunk

      out << m
    end

    out
  end

  def generate_message_no_recipients
    this = self

    m = Mail.new do
      from Kukupa.app_config["email-from"]

      if this.annotate_subject
        subject this.class.annotate_subject(this.decrypt(:subject))
      else
        subject this.decrypt(:subject)
      end

      unless this.content_text.nil?
        text_part do
          content_type 'text/plain; charset=UTF-8'
          body this.decrypt(:content_text)
        end
      end

      unless this.content_html.nil?
        html_part do
          content_type 'text/html; charset=UTF-8'
          body this.decrypt(:content_html)
        end
      end

      unless this.attachments.nil?
        attachments = JSON.parse(this.decrypt(:attachments))
        attachments.each do |at|
          add_file :filename => at["filename"], :content => at["content"]
        end
      end
    end

    m.header["Return-Path"] = "<>"
    m.header["Auto-Submitted"] = "auto-generated"

    m
  end
end
