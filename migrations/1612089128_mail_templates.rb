Sequel.migration do
  change do
    create_table :mail_templates do
      primary_key :id

      String :name, null: false
      String :content, null: false
      TrueClass :enabled, null: false, default: true

      DateTime :creation, null: false, default: Sequel.function(:NOW)
      DateTime :edited, null: true
    end
  end
end
