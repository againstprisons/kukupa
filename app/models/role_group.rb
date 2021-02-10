class Kukupa::Models::RoleGroup < Sequel::Model
  one_to_many :role_group_users
  one_to_many :role_group_roles
end
