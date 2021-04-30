Sequel.migration do
  change do
    alter_table :cases do
      add_column :show_overrides, String, null: false, default: '{}'
    end
  end
end
