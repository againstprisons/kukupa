Sequel.migration do
  change do
    create_table :prison_assignees do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)
      
      foreign_key :prison, :prisons, null: false
      foreign_key :user, :users, null: false
    end
  end
end
