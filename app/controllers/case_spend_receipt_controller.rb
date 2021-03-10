class Kukupa::Controllers::CaseSpendReceiptController < Kukupa::Controllers::CaseController
  add_route :get, '/'

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end
  end

  def index(cid, sid)
    @spend = Kukupa::Models::CaseSpend[sid.to_i]
    return halt 404 unless @spend
    return halt 404 unless @spend.case == @case.id

    receipt_file = @spend.decrypt(:receipt_file)
    if receipt_file
      @receipt = Kukupa::Models::File.where(file_id: receipt_file).first
    end
    return halt 404 unless @receipt

    @case_name = @case.get_name
    @title = t(:'case/spend/receipt/title', name: @case_name, spend_id: @spend.id)

    @dl_token = @receipt.generate_download_token(@user)
    @url_dl = url("/filedl/#{@receipt.file_id}/#{@dl_token.token}")
    @url_view = Addressable::URI.parse(@url_dl)
    @url_view.query_values = {v: 1}

    return haml(:'case/spend/receipt', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      spend_obj: @spend,
      spend_receipt: @receipt,
      download_url: @url_dl,
      view_url: @url_view,
    })
  end
end
