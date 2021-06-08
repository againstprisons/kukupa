Sequel.migration do
  change do
    alter_table :users do
      add_column :admin_notes, String, null: true
    end
  end
end
