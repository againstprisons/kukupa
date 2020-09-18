Sequel.migration do
  change do
    alter_table :case_notes do
      add_column :metadata, String, null: true
    end
  end
end
