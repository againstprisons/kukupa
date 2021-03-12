Sequel.migration do 
  change do 
    alter_table :users do
      add_column :privacy_agreement_okay, TrueClass, null: false, default: false
    end
  end
end
