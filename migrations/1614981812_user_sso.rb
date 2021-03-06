Sequel.migration do
  change do
    alter_table :users do
      add_column :sso_method, String, null: true
      add_column :sso_external_id, String, null: true
    end
  end
end
