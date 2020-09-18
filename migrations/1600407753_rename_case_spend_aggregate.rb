Sequel.migration do
  up do
    rename_table :case_spend_years, :case_spend_aggregates

    alter_table :case_spend_aggregates do
      add_column :month, String
    end
  end

  down do
    alter_table :case_spend_aggregates do
      drop_column :month
    end

    rename_table :case_spend_aggregates, :case_spend_years
  end
end
