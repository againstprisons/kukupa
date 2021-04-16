Sequel.migration do
  change do
    alter_table :mail_templates do
      add_column :group, String, null: true
    end
  end
end
