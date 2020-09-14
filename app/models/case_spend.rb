class Kukupa::Models::CaseSpend < Sequel::Model
  def get_year
    self.creation.strftime("%Y")
  end
end

class Kukupa::Models::CaseSpendYear < Sequel::Model
  def self.create_aggregate_for_case(c)
    c = c.id if c.respond_to?(:id)

    # construct a hash where the key is the year, as a string, and the value
    # is an integer of the spend for that year
    years = {}
    Kukupa::Models::CaseSpend.where(case: c).each do |spend|
      years[spend.get_year] ||= 0
      years[spend.get_year] += spend.decrypt(:amount).to_i
    end

    # destroy the existing aggregates for this case
    self.where(case: c).delete

    # create new aggregates
    years.keys.map do |year|
      ag = self.new(case: c)
      ag.save # save to get ID

      ag.year_search = Kukupa::Crypto.index('CaseSpendYear', 'year_search', year)
      ag.encrypt(:year, year)
      ag.encrypt(:amount, years[year])
      ag.save

      ag
    end
  end

  def self.get_case_year(c, year)
    c = c.id if c.respond_to?(:id)
    year = year.strftime("%Y") if year.respond_to?(:strftime)
    year_search = Kukupa::Crypto.index('CaseSpendYear', 'year_search', year)

    self.where(case: c, year_search: year_search).first
  end
end
