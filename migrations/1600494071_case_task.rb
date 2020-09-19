Sequel.migration do
  change do
    create_table :case_tasks do
      primary_key :id

      DateTime :creation, null: false, default: Sequel.function(:NOW)
      DateTime :completion, null: true

      foreign_key :case, :cases, null: false
      foreign_key :author, :users, null: false
      foreign_key :assigned_to, :users, null: false

      String :content
    end

    create_table :case_task_updates do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :task, :case_tasks, nulL: false
      foreign_key :author, :users, null: false

      String :update_type
      String :data
    end
  end
end
