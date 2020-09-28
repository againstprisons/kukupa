Sequel.migration do
  change do
    alter_table :case_spends do
      add_column :approved, DateTime, null: true
    end
  end
end
