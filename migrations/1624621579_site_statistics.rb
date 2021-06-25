Sequel.migration do
  change do
    create_table :site_statistics do
      primary_key :id
      DateTime :date

      Integer :user_count
      Integer :case_count
      Integer :spend_count
      Integer :spend_total
      Integer :correspondence_count
      Integer :note_count
      Integer :task_count
    end

    create_table :site_case_statistics do
      primary_key :id
      DateTime :date

      String :case_type
      String :case_purpose

      Integer :case_count
      Integer :spend_count
      Integer :spend_total
      Integer :correspondence_count
      Integer :note_count
      Integer :task_count
    end
  end
end
