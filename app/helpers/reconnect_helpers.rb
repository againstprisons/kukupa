module Kukupa::Helpers::ReconnectHelpers
  def reconnect_penpal(opts = {})
    %w[reconnect-api-key reconnect-url reconnect-penpal-id].each do |k|
      return nil unless Kukupa.app_config[k]
    end

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
    %w[reconnect-api-key reconnect-url reconnect-penpal-id].each do |k|
      return nil unless Kukupa.app_config[k]
    end

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
  
  def reconnect_create_relationship(penpal_one, penpal_two)
    %w[reconnect-api-key reconnect-url reconnect-penpal-id].each do |k|
      return nil unless Kukupa.app_config[k]
    end
    
    req_opts = {
      method: :post,
      body: {
        token: Kukupa.app_config['reconnect-api-key'],
        penpal_one: penpal_one, 
        penpal_two: penpal_two,
        note: "<p>This relationship was created automatically by Kūkupa.</p>",
      },
    }

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/penpal/relationship/create'

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    return nil unless response.success?

    begin
      data = JSON.parse(response.body)
    rescue => e
      return nil
    end

    data
  end
  
  def reconnect_create_penpal(opts = {})
    %w[reconnect-api-key reconnect-url reconnect-penpal-id].each do |k|
      return nil unless Kukupa.app_config[k]
    end
    
    req_body = opts.merge({
      token: Kukupa.app_config['reconnect-api-key'],
      note: "<p>This penpal was created automatically by Kūkupa.</p>",
    })

    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/penpal/create'

    response = Typhoeus::Request.new(api_url.to_s, {
      method: :post,
      body: req_body,
    }).run

    return nil unless response.success?

    begin
      data = JSON.parse(response.body)
    rescue => e
      return nil
    end

    data
  end
  
  def reconnect_create_penpal_from_case(case_obj, opts = {})
    pp_name_first = case_obj.decrypt(:first_name)&.strip
    pp_name_first = nil if pp_name_first&.empty?
    pp_name_middle = case_obj.decrypt(:middle_name)&.strip
    pp_name_middle = nil if pp_name_middle&.empty?
    pp_name_last = case_obj.decrypt(:last_name)&.strip
    pp_name_last = nil if pp_name_last&.empty?
    pp_pseudonym = case_obj.decrypt(:pseudonym)&.strip
    pp_pseudonym = nil if pp_pseudonym&.empty?
    prn = case_obj.decrypt(:prisoner_number)&.strip
    prn = nil if prn&.empty?
    prison = Kukupa::Models::Prison[case_obj.decrypt(:prison).to_i]

    reconnect_create_penpal({
      name_first: pp_name_first,
      name_middle: pp_name_middle,
      name_last: pp_name_last,
      pseudonym: pp_pseudonym,
      prn: prn,
      prison: prison&.reconnect_id,
    }.merge(opts))
  end
end
