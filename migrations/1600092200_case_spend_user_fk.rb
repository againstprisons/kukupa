Sequel.migration do
  change do
    alter_table :case_spends do
      add_foreign_key :author, :users, null: true
      add_foreign_key :approver, :users, null: true
    end
  end
end
