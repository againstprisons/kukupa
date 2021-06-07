module Kukupa::Config::UidList
  module_function

  def order
    -10000
  end

  def accept?(key, type)
    type == :uid_list
  end

  def parse(value)
    uids = value&.split(',')&.map(&:strip)&.map(&:to_i)
    uids = [] if uids.nil?
    valid_uids = uids.map do |uid|
      Kukupa::Models::User[uid]&.id
    end

    if valid_uids.count != uids.count
      return {
        :warning => (
          "Some UIDs in the list did not belong to valid users, " +
          "these have been ignored"
        ),
        :data => valid_uids,
      }
    end
    
    {
      :data => valid_uids,
    }
  end
end
