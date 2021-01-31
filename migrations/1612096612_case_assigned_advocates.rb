# This migration is a bit complex. Sorry!
#
# The up migration creates a new table for case assigned advocates, creates
# a new entry in that table for the assigned advocate for each case (if the
# case has an assigned advocate), and then drops the assigned advocate field
# on the case itself.
#
# The down migration does the opposite - it adds the assigned advocate field
# back to the case table, selects an assigned advocate for each case from the
# to-be-deleted table (ordering by creation, so the "first" assigned advocate
# for the case is selected), updates the case with that advocate, and then
# drops the assigned advocates table.
#
# I hope that made sense!

Sequel.migration do
  # This has to be done in a transaction. If something happens, we risk losing
  # who is the assigned advocate for _every case_
  transaction

  up do
    # Create the new assigned advocate table
    create_table :case_assigned_advocates do
      primary_key :id
      DateTime :creation, null: false, default: Sequel.function(:NOW)

      foreign_key :case, :cases, null: false
      foreign_key :user, :users, null: false
    end
    
    # For every case ...
    from(:cases).each do |c|
      # ... (skipping cases where there is no assigned advocate) ...
      next unless c[:assigned_advocate]

      # ... create a new CaseAssignedAdvocate for the assigned advocate.
      from(:case_assigned_advocates)
        .insert(case: c[:id], user: c[:assigned_advocate])
    end
    
    # And then drop the old `assigned_advocate` column on the Case.
    alter_table :cases do
      drop_column :assigned_advocate
    end
  end

  down do
    # Create the `assigned_advocate` foreign key on the case table
    alter_table :cases do
      add_foreign_key :assigned_advocate, :users, null: true
    end
    
    # For every case...
    from(:cases).each do |c|
      # ... get the assigned advocate with the oldest creation timestamp ...
      adv = from(:case_assigned_advocates)
        .where(case: c[:id])
        .order(Sequel.asc(:creation))
        .first

      # ... (skipping this case if there isn't an assigned advocate) ...
      next unless adv
      
      # ... and save the chosen assigned advocate to the case object.
      from(:cases)
        .where(id: c[:id])
        .update(assigned_advocate: adv[:user])
    end
    
    # And then drop the CaseAssignedAdvocate table altogether.
    drop_table :case_assigned_advocates
  end
end
