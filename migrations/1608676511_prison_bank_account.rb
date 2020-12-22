Sequel.migration do
  change do
    alter_table :prisons do
      add_column :bank_account, String, null: true
    end
  end
end
