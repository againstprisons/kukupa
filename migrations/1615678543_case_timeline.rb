Sequel.migration do
  change do
    create_table :case_timeline_entries do
      primary_key :id
      foreign_key :case, :cases, null: false

      DateTime :date, null: false
      String :name, null: true
      String :description, null: true

      foreign_key :creator, :users, null: true
      DateTime :creation, null: false, default: Sequel.function(:NOW)
      DateTime :reminded, null: true
    end
  end
end
