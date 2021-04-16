module Kukupa::Helpers::ApiHelpers
  def valid_api_token?(opts = {})
    token = request.params['token']&.strip&.downcase
    model = Kukupa::Models::Token.where(token: token, use: 'apikey', valid: true).first
    if model && model.check_validity!
      return [true, nil]
    end

    if opts[:allow_user_session] && session.key?(:token)
      s_model = Kukupa::Models::Token.where(token: session[:token], use: 'session', valid: true).first
      if s_model && s_model.check_validity!
        return [true, s_model.user]
      end
    end

    [false, nil]
  end

  def api_json(data)
    content_type 'application/json'
    JSON.generate(data)
  end
end
