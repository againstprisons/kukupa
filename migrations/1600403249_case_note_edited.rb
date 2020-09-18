Sequel.migration do
  change do
    alter_table :case_notes do
      add_column :edited, DateTime, null: true
    end
  end
end
