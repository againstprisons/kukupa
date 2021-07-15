Sequel.migration do
  change do
    alter_table :case_notes do
      add_column :hidden_admin_only, TrueClass, null: false, default: false
      add_column :hidden_collapsed, TrueClass, null: false, default: false
    end
  end
end
