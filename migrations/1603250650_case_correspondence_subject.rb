Sequel.migration do
  change do
    alter_table :case_correspondence do
      add_column :subject, String, null: true
    end
  end
end
