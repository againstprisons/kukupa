Sequel.migration do
  change do
    create_table :role_groups do
      primary_key :id

      String :name
      TrueClass :requires_2fa, null: false, default: true
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end

    create_table :role_group_users do
      primary_key :id

      foreign_key :user_id, :users, null: false
      foreign_key :role_group_id, :role_groups, null: false
      DateTime :created, null: false, default: Sequel.function(:NOW)
    end

    create_table :role_group_roles do
      primary_key :id

      foreign_key :role_group_id, :role_groups, null: false
      String :role, null: false
    end
  end
end
