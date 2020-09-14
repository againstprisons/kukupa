class Kukupa::Models::CaseNote < Sequel::Model
  many_to_one :case
end
