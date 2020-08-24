class Kukupa::Models::UserRole < Sequel::Model
  many_to_one :user
end
