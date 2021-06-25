Sequel.migration do
  change do
    alter_table :case_correspondence do
      add_column :email_reply_to, String, null: true
    end
  end
end
