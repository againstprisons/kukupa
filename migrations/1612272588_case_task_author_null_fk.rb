Sequel.migration do
  up do
    alter_table :case_tasks do
      set_column_allow_null :author
    end
  end

  down do
    alter_table :case_tasks do
      set_column_not_null :author
    end
  end
end
