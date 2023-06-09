class Kukupa::Controllers::CaseController < Kukupa::Controllers::ApplicationController
  def before(*args)
    @user = current_user
    @case = Kukupa::Models::Case[args.first.to_i]
    if @case
      # bail on unknown type
      unless Kukupa::Models::Case::CASE_TYPES.keys.include?(@case.type.to_sym)
        out = haml(:'case/errors/unknown_type', layout: :layout_minimal, locals: {
          title: t(:'case/unknown_type/title'),
          case_obj: @case,
        })

        halt out
      end
    end
  end
end
