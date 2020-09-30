Sequel.migration do
  change do
    create_table :case_filters do
      primary_key :id
      foreign_key :case, :cases

      String :filter_label
      String :filter_value
    end
  end
end
