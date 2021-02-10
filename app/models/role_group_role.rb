class Kukupa::Models::RoleGroupRole < Sequel::Model
  many_to_one :role_group
end

