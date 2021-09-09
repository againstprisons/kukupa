Sequel.migration do
  change do
    create_table :case_unassigned_new_requests do
      primary_key :id
      foreign_key :case, :cases, null: false
      DateTime :request_ts, null: false
      DateTime :creation, null: false, default: Sequel.function(:NOW)
    end
  end
end
