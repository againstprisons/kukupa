Sequel.migration do
  change do
    alter_table :case_spends do
      add_column :receipt_file, String, null: true
    end
  end
end
