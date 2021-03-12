Sequel.migration do 
  change do 
    alter_table :cases do
      add_column :duration, String, null: false, default: 'short'
    end
  end
end
