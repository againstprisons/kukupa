class Kukupa::Models::CaseSpend < Sequel::Model
  def get_year
    self.creation.strftime("%Y")
  end
end

class Kukupa::Models::CaseSpendYear < Sequel::Model
  def self.create_aggregate_for_case(c)
    c = c.id if c.respond_to?(:id)

    # construct a hash where the key is the year, as a string, and the value
    # is a float of the spend for that year
    years = {}
    Kukupa::Models::CaseSpend.where(case: c).each do |spend|
      # Skip unapproved spends in total
      next if spend.approver.nil?

      years[spend.get_year] ||= 0.0
      years[spend.get_year] += spend.decrypt(:amount).to_f
    end

    # destroy the existing aggregates for this case
    self.where(case: c).delete

    # create new aggregates, converting the amount to an integer
    years.keys.map do |year|
      ag = self.new(case: c, year: year)
      ag.save # save to get ID

      ag.encrypt(:amount, years[year].to_i)
      ag.save

      ag
    end
  end

  def self.get_case_year(c, year)
    c = c.id if c.respond_to?(:id)
    year = year.strftime("%Y") if year.respond_to?(:strftime)

    self.where(case: c, year: year).first
  end
end
