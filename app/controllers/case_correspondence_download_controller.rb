class Kukupa::Controllers::CaseCorrespondenceDownloadController < Kukupa::Controllers::CaseController
  add_route :get, '/'
  add_route :get, '/print', method: :print

  include Kukupa::Helpers::EmailTemplateHelpers

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

    @content = @content.force_encoding("UTF-8")

    if @ccobj.correspondence_type == 'email'
      ###
      # XXX: This is hacky as hell.
      #
      # Basically what we're doing here is  replicating what happens 
      # inside the EmailQueue#new_from_template function - rendering the
      # HTML version of the email reply template with our correspondence
      # content embedded, and the case's email identifier passed in, so
      # the result looks pretty much like what the actual email looks like. 
      #
      # Because we want the output of this to act like the print view for
      # normal correspondence, we render the content of the <head> section 
      # of the normal print view, embedded in a literal-string Haml call to
      # render the <head> element itself, and then we prepend that to the
      # email template render output.
      #
      # If I were to refactor this, I'd make a separate view (something like
      # :'case/correspondence/print/email_reply' maybe), and use the proper
      # Sinatra-provided ERB renderer to render the email reply template,
      # rather than using the `new_tilt_template_from_fn` function from the
      # EmailTemplateHelpers. For now, this works. 
      ###

      # create the EmailData instance with our case email identifier
      template_data = Kukupa::Models::EmailQueue::EmailData.new({
        email_identifier: @case.email_identifier,
      })

      # create the email reply layout using the email helpers, and render the
      # template with our correspondence content embedded
      template = new_tilt_template_from_fn('reply_layout.html.erb')
      output = template.render(template_data) { @content }

      # render the normal print view <head> section
      html_head = haml("!!!html5\n%head= yield", layout: false) do
        haml(:'case/correspondence/print/head', layout: false, locals: {title: @title})
      end

      # return the combination of the print view <head> and our email template
      return [html_head, output].join("\n")

    else
      locals = {
        title: @title,
        case_obj: @case,
        ccobj: @ccobj
      }

      haml(:'case/correspondence/print/index', layout: false, locals: locals) do
        @content
      end
    end
  end
end
