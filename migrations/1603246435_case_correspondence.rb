Sequel.migration do
  change do
    create_table :case_correspondence do
      primary_key :id
      foreign_key :case, :cases, null: false

      TrueClass :sent_by_us, null: false, default: true

      Integer :reconnect_id, null: true
      String :file_id, null: true
      String :file_type, null: false, default: "no_file"

      DateTime :creation, null: false, default: Sequel.function(:NOW)
    end
  end
end
