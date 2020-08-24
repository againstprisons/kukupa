Sequel.migration do
  change do
    create_table :config do
      primary_key :id

      String :key
      String :value
      String :type
    end

    create_table :users do
      primary_key :id

      String :name
      String :email, null: false
      String :preferred_language

      String :password_hash
      TrueClass :totp_enabled
      String :totp_secret

      DateTime :created, null: false, default: Sequel.function(:NOW)
    end

    create_table :user_roles do
      primary_key :id
      foreign_key :user_id, :users

      String :role, null: false
    end

    create_table :tokens do
      primary_key :id
      foreign_key :user_id, :users, null: true

      String :token, null: false
      String :use, null: false

      DateTime :created, null: false, default: Sequel.function(:NOW)
      DateTime :expiry, null: true
      TrueClass :valid, null: false, defauld: true

      String :extra_data
    end
  end
end
