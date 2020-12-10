Sequel.migration do
  change do
    alter_table :cases do
      add_column :global_note, String, null: true
    end
  end
end
