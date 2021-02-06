module Kukupa::Helpers::CaseListHelpers
  # This function returns a hash, where the key is the translation key for
  # the portion of the case list (the value of that key).
  def case_list_get_cases(opts = {})
    opts[:sort] ||= :assigned
    opts[:is_open] ||= true

    advocates = {}
    prisons = {}

    ds = Kukupa::Models::Case
      .where(is_open: opts[:is_open])

    # get initial case info
    cases = ds.map do |c|
      url = Addressable::URI.parse(url("/case/#{c.id}/view"))
      prison = c.decrypt(:prison).to_i
      prisons[prison.to_s] ||= Kukupa::Models::Prison[prison]

      {
        :obj => c,
        :id => c.id,
        :name => c.get_name,
        :url => url.to_s,
        :open => c.is_open,
        :prison => prisons[prison.to_s],
        :prn => c.decrypt(:prisoner_number),
        :purpose => c.purpose,
      }
    end

    # get advocate details
    cases.map! do |c|
      c[:advocates] = []

      assigned = Kukupa::Models::CaseAssignedAdvocate
        .where(case: c[:id])
        .map(&:user)

      assigned.each do |aa|
        advocates = case_populate_advocate(advocates, aa)
        c[:advocates] << advocates[aa.to_s]
      end

      c
    end

    # sort by whether cases have an assigned advocate - unassigned at the top
    cases.sort! do |a, b|
      (a[:advocates].empty?() ? 0 : 1) <=> (b[:advocates].empty?() ? 0 : 1)
    end

    case opts[:sort]
    when :purpose
      purposes = {}
      cases.each do |c|
        purposes["case_purpose/#{c[:purpose]}".to_sym] ||= []
        purposes["case_purpose/#{c[:purpose]}".to_sym] << c
      end

      purposes

    else # when :assigned
      assigned = cases.reject { |x| x[:advocates].empty? }
      unassigned = cases.filter { |x| x[:advocates].empty? }

      {
        :'case/list/sort/assigned/unassigned' => unassigned,
        :'case/list/sort/assigned/assigned' => assigned,
      }
    end
  end
end
