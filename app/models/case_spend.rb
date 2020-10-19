class Kukupa::Models::CaseSpend < Sequel::Model
  def anchor
    "CaseSpend-#{self.id}"
  end

  def get_year
    self.creation.strftime("%Y")
  end

  def delete!
    Kukupa::Models::CaseSpendUpdate
      .where(spend: self.id)
      .map(&:delete)

    self.delete
  end
end

class Kukupa::Models::CaseSpendUpdate < Sequel::Model
  def anchor
    "CaseSpendUpdate-#{self.id}"
  end
end

class Kukupa::Models::CaseSpendAggregate < Sequel::Model
  def self.create_aggregate_for_case(c)
    c = c.id if c.respond_to?(:id)

    # construct a hash of spending, where the keys of the `years` hash are
    # the year as a string (like '2020') and the value is a hash where the
    # keys are the year and month (like '2020-01') and the values of THAT
    # are the spending for that month.
    years = {}
    Kukupa::Models::CaseSpend.where(case: c).each do |spend|
      # Skip unapproved spends in total
      next if spend.approver.nil?

      year = spend.creation.strftime('%Y')
      month = spend.creation.strftime('%Y-%m')

      years[year] ||= {}
      years[year][month] ||= 0.0
      years[year][month] += spend.decrypt(:amount).to_f
    end

    # destroy the existing aggregates for this case
    self.where(case: c).delete

    # create new aggregates, converting the amount to an integer
    years.keys.map do |year|
      years[year].keys.map do |month|
        ag = self.new(case: c, year: year, month: month).save
        ag.encrypt(:amount, years[year][month].to_i)
        ag.save

        ag
      end
    end.flatten
  end

  def self.get_case_month(c, ym)
    c = c.id if c.respond_to?(:id)
    ym = ym.strftime("%Y-%m") if ym.respond_to?(:strftime)

    self.where(case: c, month: ym).first&.decrypt(:amount).to_f
  end

  def self.get_case_year_total(c, year)
    c = c.id if c.respond_to?(:id)
    year = year.strftime("%Y") if year.respond_to?(:strftime)

    total = 0.0
    self.where(case: c, year: year).each do |e|
      total += e.decrypt(:amount).to_f
    end

    total
  end

  def self.get_month_total(ym)
    ym = ym.strftime("%Y-%m") if ym.respond_to?(:strftime)

    total = 0.0
    self.where(month: ym).each do |e|
      total += e.decrypt(:amount).to_f
    end

    total
  end

  def self.get_year_total(year)
    year = year.strftime("%Y") if year.respond_to?(:strftime)

    total = 0.0
    self.where(year: year).each do |e|
      total += e.decrypt(:amount).to_f
    end

    total
  end
end
