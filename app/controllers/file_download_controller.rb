class Kukupa::Controllers::FileDownloadController < Kukupa::Controllers::ApplicationController
  add_route :get, "/:fileid/:token"

  def index(fid, token)
    @token = Kukupa::Models::Token.where(token: token, use: 'file_download').first
    return halt 404 unless @token
    return halt 404 unless @token.check_validity!

    if @token.user_id
      return halt 404 unless @token.user_id == current_user&.id
    end

    @file = Kukupa::Models::File.where(file_id: fid).first
    return halt 404 unless @file
    return halt 404 unless @token.extra_data == @file.file_id

    data = @file.decrypt_file

    content_type @file.mime_type
    attachment @file.generate_fn unless request.params['v'].to_i.positive?
    return data
  end
end
