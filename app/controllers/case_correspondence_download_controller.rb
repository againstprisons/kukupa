class Kukupa::Controllers::CaseCorrespondenceDownloadController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :get, '/print', method: :print

  def before(cid, *args)
    super
    return halt 404 unless logged_in?

    @case = Kukupa::Models::Case[cid]
    return halt 404 unless @case && @case.is_open
    unless has_role?('case:view_all')
      return halt 404 unless @case.can_access?(@user)
    end
  end

  def index(cid, ccid)
    @ccobj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @ccobj
    return halt 404 unless @ccobj.case == @case.id

    @type = @ccobj.file_type
    @download_url = @ccobj.get_download_url(user: @user)

    unless @download_url
      case @type
      when "reconnect"
        flash :error, t(:'case/correspondence/download/errors/no_reconnect_response')
      else
        flash :error, t(:'case/correspondence/download/errors/unknown_error')
      end

      return redirect back
    end

    @view_url = Addressable::URI.parse(@download_url)
    @view_url.query_values = {v: 1}

    @case_name = @case.get_name
    @title = t(:'case/correspondence/download/title', name: @case_name, ccid: @ccobj.id)

    return haml(:'case/correspondence/download', :locals => {
      title: @title,
      case_obj: @case,
      case_name: @case_name,
      cc_obj: @ccobj,
      cc_type: @type,
      view_url: @view_url,
      download_url: @download_url,
    })
  end

  def print(cid, ccid)
    @ccobj = Kukupa::Models::CaseCorrespondence[ccid.to_i]
    return halt 404 unless @ccobj
    return halt 404 unless @ccobj.case == @case.id

    @title = t(:'case/correspondence/download/print/title', ccid: @ccobj.id)

    @content = @ccobj.get_file_content
    unless @content
      case @ccobj.file_type
      when "reconnect"
        flash :error, t(:'case/correspondence/download/errors/no_reconnect_response')
      else
        flash :error, t(:'case/correspondence/download/errors/unknown_error')
      end

      return redirect back
    end

    @mime = MimeMagic.by_magic(@content)&.type
    if @content&.include?('<p>') && @content&.include?('</p>')
      @mime = 'text/html'
    end

    unless %w[text/html text/plain].include?(@mime)
      flash :error, t(:'case/correspondence/download/print/errors/invalid_mime')
      return redirect back
    end

    haml(:'case/correspondence/print/index', layout: false, locals: {title: @title, case_obj: @case, ccobj: @ccobj}) do
      @content
    end
  end
end
