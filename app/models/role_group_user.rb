class Kukupa::Models::RoleGroupUser < Sequel::Model
  many_to_one :user
  many_to_one :role_group
end
