Sequel.migration do
  change do
    alter_table :cases do
      # `type` is unencrypted, set to "case" for normal cases (default),
      # or "project" for projects.
      add_column :type, String, null: false, default: 'case'

      # The `is_private` flag has no effect for normal cases - only
      # assigned users will be able to see those (and the flag won't be
      # editable for normal cases). For projects, it controls whether
      # the project can be seen by all users (`is_private = false`), or
      # only users assigned to it (`is_private = true`).
      add_column :is_private, TrueClass, null: false, default: false
    end
  end 
end
