module Kukupa::Helpers::CaseIndexHelpers
  def case_index_populate_advocate(advocates, uid)
    unless advocates.key?(uid.to_s)
      adv = Kukupa::Models::User[uid.to_i]
      advocates[uid.to_s] ||= {
        obj: adv,
        id: adv&.id || 0,
        name: adv&.decrypt(:name) || t(:'unknown'),
      }
    end

    advocates
  end

  def case_index_get_cases(opts = {})
    cuser = current_user
    advocates = {}

    cases = Kukupa::Models::Case.map do |c|
      next unless c.is_open || opts[:include_closed]

      url = Addressable::URI.parse(url("/case/#{c.id}/view"))

      {
        :obj => c,
        :id => c.id,
        :name => c.get_name,
        :url => url.to_s,
        :mine => c.assigned_advocate == cuser.id,
      }
    end

    cases.compact!
    cases.sort! { |a, b| (a[:mine] ? 1 : 0) <=> (b[:mine] ? 1 : 0) }

    # only let admins see all cases by rejecting anything that isn't :mine
    unless opts[:view_all]
      cases.reject! { |x| !x[:mine] }
    end

    # get advocate details
    cases.map! do |c|
      advocates = case_index_populate_advocate(advocates, c[:obj].assigned_advocate)
      c[:advocate] = advocates[c[:obj].assigned_advocate.to_s]

      c
    end

    # get this year's total spend for this case
    cases.map! do |c|
      spend_month = Kukupa::Models::CaseSpendAggregate.get_case_month(c[:id], DateTime.now)
      spend_year = Kukupa::Models::CaseSpendAggregate.get_case_year_total(c[:id], DateTime.now)

      c[:total_spend] = {
        month: {
          amount: spend_month,
        },
        year: {
          amount: spend_year,
          max: Kukupa.app_config['fund-max-spend-per-case-year'].to_f,
        },
      }

      c
    end

    # get last non-outside-request case note
    cases.map! do |c|
      last_note = Kukupa::Models::CaseNote
        .where(case: c[:id], is_outside_request: false)
        .reverse(:creation)
        .first

      if last_note
        advocates = case_index_populate_advocate(advocates, last_note.author)
        c[:last_note] = {
          creation: last_note.creation,
          advocate: advocates[last_note.author.to_s],
        }
      end

      c
    end

    # get last case spend
    cases.map! do |c|
      last_spend = Kukupa::Models::CaseSpend
        .where(case: c[:id])
        .exclude(approver: nil)
        .reverse(:creation)
        .first

      if last_spend
        advocates = case_index_populate_advocate(advocates, last_spend.author)
        advocates = case_index_populate_advocate(advocates, last_spend.approver)

        c[:last_spend] = {
          fid: "CaseSpend[#{last_spend.id}]",
          creation: last_spend.creation,
          amount: last_spend.decrypt(:amount).to_f,
          author: advocates[last_spend.author.to_s],
          approver: advocates[last_spend.approver.to_s],
        }
      end

      c
    end

    # get last *unapproved* case spend
    cases.map! do |c|
      last_spend = Kukupa::Models::CaseSpend
        .where(case: c[:id], approver: nil)
        .reverse(:creation)
        .first

      if last_spend
        advocates = case_index_populate_advocate(advocates, last_spend.author)

        c[:last_unapproved_spend] = {
          fid: "CaseSpend[#{last_spend.id}]",
          creation: last_spend.creation,
          amount: last_spend.decrypt(:amount).to_f,
          author: advocates[last_spend.author.to_s],
        }
      end

      c
    end

    cases
  end
end
