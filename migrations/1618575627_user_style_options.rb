Sequel.migration do
  change do
    alter_table :users do
      add_column :style_options_hash, String, null: true
    end
  end
end
