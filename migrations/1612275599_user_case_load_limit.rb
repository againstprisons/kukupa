Sequel.migration do
  change do
    alter_table :users do
      add_column :case_load_limit, Integer, null: false, default: 0
    end
  end
end