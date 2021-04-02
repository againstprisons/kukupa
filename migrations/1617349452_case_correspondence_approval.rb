Sequel.migration do
  down do
    alter_table :case_correspondence do
      drop_column :approved
      drop_column :approved_by
      drop_column :has_been_sent
    end
  end

  up do
    alter_table :case_correspondence do
      add_column :approved, TrueClass, null: false, default: false     
      add_column :approved_by, Integer, null: true, default: nil
      add_column :has_been_sent, TrueClass, null: false, default: false
    end

    from(:case_correspondence).update(approved: true, has_been_sent: true)
  end
end
