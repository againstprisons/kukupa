class Kukupa::Models::Case < Sequel::Model
  def get_name
    [
      self.decrypt(:first_name),
      self.decrypt(:middle_name),
      self.decrypt(:last_name),
    ].compact.join(' ')
  end
end
