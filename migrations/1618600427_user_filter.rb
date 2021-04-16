Sequel.migration do
  change do
    create_table :user_filters do
      primary_key :id
      foreign_key :user, :users

      String :filter_label
      String :filter_value
    end
  end
end
