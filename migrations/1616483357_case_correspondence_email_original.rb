Sequel.migration do
  change do
    alter_table :case_correspondence do
      add_column :email_original_fileid, String, null: true
    end
  end
end
