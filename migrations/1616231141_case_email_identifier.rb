Sequel.migration do
  change do
    alter_table :cases do
      add_column :email_identifier, String, null: true
    end
  end
end
