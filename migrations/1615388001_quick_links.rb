Sequel.migration do
  change do
    create_table :quick_links do
      primary_key :id
      
      String :name
      String :url
      String :icon

      Integer :sort_order
    end
  end
end
