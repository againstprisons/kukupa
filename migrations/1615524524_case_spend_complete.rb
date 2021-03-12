Sequel.migration do
  change do
    alter_table :case_spends do
      add_column :is_complete, TrueClass, null: false, default: false
    end
  end
end
