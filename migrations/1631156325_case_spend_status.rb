Sequel.migration do
  up do
    alter_table :case_spends do
      add_column :status, String, null: false, default: "waiting"
    end

    from(:case_spends).exclude(approver: nil).update(status: 'approved')
    from(:case_spends).where(approver: nil).update(status: 'waiting')
  end

  down do
    alter_table :case_spends do
      drop_column :status
    end
  end
end
