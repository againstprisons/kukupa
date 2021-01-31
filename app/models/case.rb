class Kukupa::Models::Case < Sequel::Model
  # TODO: allow multiple advocates per case
  def self.assigned_to(user)
    user = user.id if user.respond_to?(:id)
    self.where(assigned_advocate: user)
  end

  # TODO: allow multiple advocates per case
  def get_assigned_advocates
    [self.assigned_advocate].compact
  end

  def can_access?(user)
    user = user.id if user.respond_to?(:id)
    self.get_assigned_advocates.include?(user)
  end

  def get_name
    [
      self.decrypt(:first_name),
      self.decrypt(:middle_name),
      self.decrypt(:last_name),
    ].compact.join(' ')
  end

  def get_pseudonym
    ps = self.decrypt(:pseudonym)
    ps = self.decrypt(:first_name) unless ps

    ps
  end

  def delete!
    # notes
    Kukupa::Models::CaseNote.where(case: self.id).map(&:delete)

    # spends
    Kukupa::Models::CaseSpendAggregate.where(case: self.id).map(&:delete)
    Kukupa::Models::CaseSpend.where(case: self.id).each do |cs|
      Kukupa::Models::CaseSpendUpdate.where(spend: cs.id).map(&:delete)
      cs.delete
    end

    # tasks
    Kukupa::Models::CaseTask.where(case: self.id).each do |ct|
      Kukupa::Models::CaseTaskUpdate.where(task: ct.id).map(&:delete)
      ct.delete
    end

    # filters
    Kukupa::Models::CaseFilter.clear_filters_for(self)
    
    self.delete
  end
end

class Kukupa::Models::CaseFilter < Sequel::Model
  def self.clear_filters_for(case_)
    case_ = case_.id if case_.respond_to?(:id)
    self.where(case: case_).all.map(&:delete)
  end

  def self.create_filters_for(case_)
    return [] unless [:get_name, :id].map{|x| case_.respond_to?(x)}.all?

    filters = []

    # full name
    case_name = case_.get_name&.strip&.downcase
    unless case_name.nil? || case_name&.empty?
      case_name = case_name.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")

      full_name = case_name.dup
      Kukupa.filter_strip_chars.each {|x| full_name.gsub!(x, "")}

      # filter on full name
      e = Kukupa::Crypto.index("Case", "name", full_name)
      filters << self.new(case: case_.id, filter_label: "name", filter_value: e)

      # filter on partial name
      case_name.split(" ").map{|x| x.split("-")}.flatten.each do |partial|
        Kukupa.filter_strip_chars.each {|x| partial.gsub!(x, "")}

        e = Kukupa::Crypto.index("Case", "name", partial)
        filters << self.new(case: case_.id, filter_label: "name", filter_value: e)
      end
    end

    # pseudonym (but indexed as name)
    pseudonym = case_.get_pseudonym&.strip&.downcase
    unless pseudonym.nil? || pseudonym&.empty?
      pseudonym = pseudonym.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")

      full_pseudonym = pseudonym.dup
      Kukupa.filter_strip_chars.each {|x| full_pseudonym.gsub!(x, "")}

      # filter on full name
      e = Kukupa::Crypto.index("Case", "name", full_pseudonym)
      filters << self.new(case: case_.id, filter_label: "name", filter_value: e)

      # filter on partial name
      pseudonym.split(" ").map{|x| x.split("-")}.flatten.each do |partial|
        Kukupa.filter_strip_chars.each {|x| partial.gsub!(x, "")}

        e = Kukupa::Crypto.index("Case", "name", partial)
        filters << self.new(case: case_.id, filter_label: "name", filter_value: e)
      end
    end

    # prisoner number
    prn = case_.decrypt(:prisoner_number)&.to_s&.strip&.downcase
    unless prn.nil? || prn&.empty? || prn == '(unknown)'
      Kukupa.filter_strip_chars.each {|x| prn.gsub!(x, "")}
      prn = prn.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")

      e = Kukupa::Crypto.index("Case", "prisoner_number", prn)
      filters << self.new(case: case_.id, filter_label: "prisoner_number", filter_value: e)
    end

    # prison
    prison = case_.decrypt(:prison)&.strip&.downcase.to_i
    prison = Kukupa::Models::Prison[prison]
    if prison
      e = Kukupa::Crypto.index("Case", "prison", prison.id.to_s)
      filters << self.new(case: case_.id, filter_label: "prison", filter_value: e)
    end

    filters.map(&:save)
    filters
  end

  def self.perform_filter(column, search)
    column = column
      .to_s
      .strip
      .downcase

    search = search
      .to_s
      .strip
      .downcase
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")

    Kukupa.filter_strip_chars.each {|x| search.gsub!(x, "")}

    e = Kukupa::Crypto.index("Case", column, search)
    self.where(filter_label: column, filter_value: e)
  end
end
