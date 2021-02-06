Sequel.migration do 
  change do 
    alter_table :cases do
      add_foreign_key :triage_task, :case_tasks, null: true
    end
  end
end
