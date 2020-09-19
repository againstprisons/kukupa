module Kukupa::Helpers::CaseHelpers
  def case_populate_advocate(advocates, uid)
    unless advocates.key?(uid.to_s)
      adv = Kukupa::Models::User[uid.to_i]
      advocates[uid.to_s] ||= {
        obj: adv,
        id: adv&.id || 0,
        name: adv&.decrypt(:name) || t(:'unknown'),
        me: logged_in?() ? current_user.id == adv&.id : false,
      }
    end

    advocates
  end
end
