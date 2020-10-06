class Kukupa::Models::Prison < Sequel::Model
  def self.get_prisons
    self.all.map do |pr|
      {
        :id => pr.id,
        :obj => pr,
        :name => pr.decrypt(:name),
        :physical => pr.decrypt(:physical_address),
        :email => pr.decrypt(:email_address),
      }
    end
  end
end
