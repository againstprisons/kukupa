class Kukupa::Models::Case < Sequel::Model
  # Allowed case purposes
  ALLOWED_PURPOSES = %w[advocacy ppc]

  # Allowed case durations
  ALLOWED_DURATIONS = %w[short medium long]

  # Case types
  CASE_TYPES = {
    # Normal cases (this is the default)
    case: {
      fields: [
        :first_name,
        :middle_name,
        :last_name,
        :pseudonym,
        :birth_date,
        :release_date,
        :case_purpose,
        :case_duration,
        :global_note,
      ],
      show: {
        prison: true,
        reconnect: true,
        triage: true,
        correspondence: true,
        timeline: false,
      },
    },

    # Projects
    project: {
      fields: [
        {
          field: :first_name,
          tl_key: :'name/project',
        },
        :is_private,
        :global_note,
      ],
      show: {
        prison: false,
        reconnect: false,
        triage: false,
        correspondence: false,
        timeline: true,
      },
    },
  }

  # Available fields
  CASE_FIELDS = {
    first_name: {
      tl_key: :'name/first',
      type: :text,
      required: true,
    },
    middle_name: {
      tl_key: :'name/middle',
      type: :text,
    },
    last_name: {
      tl_key: :'name/last',
      type: :text,
      required: true,
    },
    pseudonym: {
      tl_key: :'pseudonym',
      type: :text,
    },
    is_private: {
      tl_key: :'case_privacy',
      type: :checkbox,
    },
    birth_date: {
      tl_key: :'birth_date',
      type: :date,
    },
    release_date: {
      tl_key: :'release_date',
      type: :date,
    },
    case_purpose: {
      tl_key: :'case_purpose',
      type: :select,
      select_options: ALLOWED_PURPOSES.map {|pr| {value: pr, tl_key: "case_purpose/#{pr}".to_sym}},
      required: true,
    },
    case_duration: {
      tl_key: :'case_duration',
      type: :select,
      select_options: ALLOWED_DURATIONS.map {|pr| {value: pr, tl_key: "case_duration/#{pr}".to_sym}},
      required: true,
    },
    global_note: {
      tl_key: :'global_note',
      type: :editor,
    },
  }
  
  class ReconnectHelpers
    extend Kukupa::Helpers::ReconnectHelpers
  end

  def self.assigned_to(user)
    user = user.id if user.respond_to?(:id)

    Kukupa::Models::CaseAssignedAdvocate
      .where(user: user)
      .map { |aa| self[aa.case] }
  end

  def get_assigned_advocates
    Kukupa::Models::CaseAssignedAdvocate
      .where(case: self.id)
      .map(&:user)
  end

  def last_updated
    dates = []

    # case notes
    dates << Kukupa::Models::CaseNote
      .select(:id, :case, :creation)
      .where(case: self.id)
      .reverse(:creation)
      .first
      &.creation

    # case tasks
    dates << Kukupa::Models::CaseTask
      .select(:id, :case, :creation)
      .where(case: self.id)
      .reverse(:creation)
      .first
      &.creation

    # case spends
    dates << Kukupa::Models::CaseSpend
      .select(:id, :case, :creation)
      .where(case: self.id)
      .reverse(:creation)
      .first
      &.creation

    # case correspondence
    dates << Kukupa::Models::CaseCorrespondence
      .select(:id, :case, :creation)
      .where(case: self.id)
      .reverse(:creation)
      .first
      &.creation

    dates.compact.sort.last
  end

  def new_mail?
    mail_date = Kukupa::Models::CaseCorrespondence
      .select(:id, :case, :creation, :sent_by_us)
      .where(case: self.id, sent_by_us: false)
      .reverse(:creation)
      .first
      &.creation

    return false unless mail_date
    last_updated <= mail_date
  end

  def field_desc(opts = {})
    CASE_TYPES[self.type.to_sym][:fields].map do |fd|
      if fd.is_a?(Symbol)
        field = CASE_FIELDS[fd]
        next unless field

        field[:name] = fd
        field

      elsif fd.is_a?(Hash)
        field = CASE_FIELDS[fd[:field]]
        next unless field

        field[:name] = fd[:field]
        field[:tl_key] = fd[:tl_key] if fd.key?(:tl_key)
        field
      end
    end.compact
  end

  def can_view?(user)
    unless self.type == 'case'
      return true if !self.is_private
    end
    
    user = user.id if user.respond_to?(:id)
    self.get_assigned_advocates.include?(user)
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
  
  def create_in_reconnect!(opts = {})
    return :not_enabled unless Kukupa.app_config['reconnect-create-penpals']

    unless opts[:skip_penpal_creation]
      res = ReconnectHelpers.reconnect_create_penpal_from_case(self)
      return :penpal_res_nil if res.nil?
      return :penpal_success_false unless res['success']
      penpal_id = res['penpal'].to_i
      return :penpal_no_id unless penpal_id.positive?
    
      self.reconnect_id = penpal_id
      self.save
    end
    
    unless opts[:skip_relationship_creation]
      return :relationship_no_reconnect_id unless self.reconnect_id.to_i.positive?
      res = ReconnectHelpers.reconnect_create_relationship(
        self.reconnect_id.to_i,
        Kukupa.app_config['reconnect-penpal-id'].to_i,
      )
      return :relationship_res_nil if res.nil?
      return :relationship_success_false unless res['success']
      return :relationship_no_id unless res['relationship'].to_i.positive?
    end

    true
  end
  
  def send_imported_case_email!(opts = {})
    case_url = Addressable::URI.parse(Kukupa.app_config['base-url'])
    case_url += "/case/#{self.id}/view"
    
    prison = Kukupa::Models::Prison[self.decrypt(:prison).to_i]

    email = Kukupa::Models::EmailQueue.new_from_template("case_imported", {
      case_obj: self,
      case_url: case_url.to_s,
      prison: prison,
    })

    email.queue_status = 'queued'
    email.encrypt(:subject, "New case imported") # TODO: tl this
    email.encrypt(:recipients, JSON.generate({
      "mode": "roles",
      "roles": ["case:alerts"],
    }))

    email.save
  end

  def close!
    # remove all assigned advocates
    Kukupa::Models::CaseAssignedAdvocate
      .where(case: self.id)
      .delete

    self.is_open = false
    self.save
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
    self.where(case: case_).delete
  end

  def self.create_filters_for(case_)
    return [] unless [:get_name, :id].map{|x| case_.respond_to?(x)}.all?
    return [] unless case_.type == 'case'

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
