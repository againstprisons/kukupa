Sequel.migration do
  up do
    alter_table :case_spend_years do
      set_column_allow_null :case
    end
  end

  down do
    alter_table :case_spend_years do
      set_column_not_null :case
    end
  end
end
