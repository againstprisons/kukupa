Sequel.migration do
  change do
    alter_table :case_spends do
      add_column :is_reimbursement, TrueClass, null: false, default: false
      add_column :reimbursement_info, String, null: true
    end
  end
end
