Sequel.migration do
  change do
    alter_table :email_queue do
      add_column :message_opts, String, null: true
    end
  end
end
