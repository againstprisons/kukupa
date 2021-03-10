class Kukupa::Controllers::CaseController < Kukupa::Controllers::ApplicationController
  def before(*args)
    @user = current_user
    @case = Kukupa::Models::Case[args.first.to_i]
  end
end
