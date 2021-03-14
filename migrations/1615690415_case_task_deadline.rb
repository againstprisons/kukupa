Sequel.migration do
  change do
    alter_table :case_tasks do
      add_column :deadline, DateTime, null: true
    end
  end
end
