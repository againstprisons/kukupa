Sequel.migration do
  change do
    alter_table :cases do
      add_column :reconnect_last_sync, DateTime, null: true
    end
  end
end
