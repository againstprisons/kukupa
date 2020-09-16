Sequel.migration do
  change do
    alter_table :case_spends do
      add_column :notes, String, null: true
    end
  end
end
