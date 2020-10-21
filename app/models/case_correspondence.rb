class Kukupa::Models::CaseCorrespondence < Sequel::Model(:case_correspondence)
  def anchor
    "CaseCorrespondence-#{self.id}"
  end

  def get_download_url
    meth = "get_download_url_#{self.file_type}".to_sym
    return self.send(meth) if self.respond_to?(meth)
    nil
  end

  def get_download_url_reconnect
    api_url = Addressable::URI.parse(Kukupa.app_config['reconnect-url'])
    api_url += '/api/dltoken'

    req_opts = {
      method: :post,
      body: {
        fileid: self.file_id,
        token: Kukupa.app_config['reconnect-api-key'],
      },
    }

    response = Typhoeus::Request.new(api_url.to_s, req_opts).run
    return nil unless response.success?

    begin
      data = JSON.parse(response.body)
    rescue => e
      return nil
    end

    return nil unless data['success']
    data['url']
  end
end
