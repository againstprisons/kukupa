Sequel.migration do
  change do
    alter_table :case_correspondence do
      add_column :correspondence_type, String, null: false, default: 'prisoner'
      add_column :target_email, String, null: true
      add_column :email_messageid, String, null: true
    end
  end
end
