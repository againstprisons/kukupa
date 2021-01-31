Sequel.migration do
  change do
    create_table :files do
      primary_key :id
      String :file_id

      DateTime :creation
      String :file_hash
      String :mime_type
      String :original_fn
    end
  end
end
