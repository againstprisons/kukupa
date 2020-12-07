module Kukupa::Helpers::ReconnectHelpers
  def reconnect_penpal(opts = {})
    return nil unless Kukupa.app_config['reconnect-api-key']
    return nil unless Kukupa.app_config['reconnect-url']

    req_opts = {
      method: :post,
      body: {
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    if opts[:cid]
      req_opts[:body][:cid] = opts[:cid]
    elsif opts[:prn]
      req_opts[:body][:prn] = opts[:prn]
    else
      return nil
    end

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/penpal'

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    return nil unless response.success?

    begin
      data = JSON.parse(response.body)
    rescue => e
      return nil
    end

    data
  end

  def reconnect_send_mail(cid, content, opts = {})
    return nil unless Kukupa.app_config['reconnect-api-key']
    return nil unless Kukupa.app_config['reconnect-url']

    opts[:mime_type] ||= 'text/html'

    tmpfile = Tempfile.new('kukupa-mail')
    tmpfile.write(content)
    tmpfile.rewind

    req_opts = {
      method: :post,
      headers: {
        ContentType: 'multipart/form-data',
      },
      body: {
        token: Kukupa.app_config['reconnect-api-key'],
        sending: Kukupa.app_config['reconnect-penpal-id'],
        receiving: cid,
        mime: opts[:mime_type],
        file: tmpfile,
      },
    }

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/correspondence/create'

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    unless response.success?
      raise "Request failure: #{response.body.inspect}"
    end

    begin
      data = JSON.parse(response.body)
    rescue => e
      raise "Failed to parse JSON: #{e.inspect}"
    end

    tmpfile.close
    tmpfile.unlink

    data
  end
end
