Sequel.migration do
  change do
    create_table :email_queue do
      primary_key :id

      DateTime :creation, null: false, default: Sequel.function(:NOW)
      String :recipients
      String :subject

      String :content_text
      String :content_html
      String :attachments

      String :queue_status, null: false
      TrueClass :annotate_subject, null: false, default: true
    end
  end
end
