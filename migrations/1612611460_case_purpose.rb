Sequel.migration do 
  change do 
    alter_table :cases do
      add_column :purpose, String, null: false, default: 'advocacy'
    end
  end
end
