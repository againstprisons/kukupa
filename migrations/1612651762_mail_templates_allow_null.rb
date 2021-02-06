Sequel.migration do
  up do
    alter_table :mail_templates do
      set_column_allow_null :name
      set_column_allow_null :content
    end
  end

  down do
    alter_table :mail_templates do
      set_column_not_null :name
      set_column_not_null :content
    end
  end
end
