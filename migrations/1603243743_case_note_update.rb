Sequel.migration do
  change do
    create_table :case_note_updates do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :note, :case_notes, null: false
      foreign_key :author, :users, null: false

      String :update_type
      String :data
    end
  end
end
