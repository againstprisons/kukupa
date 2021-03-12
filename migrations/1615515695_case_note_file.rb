Sequel.migration do
  change do
    alter_table :case_notes do
      add_column :file_id, String, null: true
    end
  end
end
