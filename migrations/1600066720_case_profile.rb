Sequel.migration do
  change do
    create_table :cases do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :assigned_advocate, :users, null: true
      String :reconnect_id

      String :first_name
      String :middle_name
      String :last_name
      String :pseudonym

      String :prison
      String :prisoner_number

      String :birth_date
      String :release_date

      TrueClass :is_open, null: false, default: true
    end

    create_table :case_notes do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :case, :cases, null: false
      foreign_key :author, :users, null: true

      TrueClass :is_outside_request, null: false, default: false
      String :content
    end

    create_table :case_spends do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :case, :cases, null: false
      String :amount
    end

    create_table :case_spend_years do
      primary_key :id

      foreign_key :case, :cases, null: false
      String :year_search
      String :year
      String :amount
    end
  end
end
