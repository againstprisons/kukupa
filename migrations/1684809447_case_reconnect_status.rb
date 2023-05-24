Sequel.migration do
  change do
    alter_table :cases do
      add_column :reconnect_status, String, null: true
    end
  end
end
