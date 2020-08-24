module Kukupa::Helpers::CsrfHelpers
  def csrf_set!
    session[:csrf] ||= Kukupa::Crypto.generate_token
    response.set_cookie('authenticity_token', {
      value: session[:csrf],
      expired: Time.now + (60 * 60 * 24 * 30), # 30 days
      path: '/',
      httponly: true,
    })
  end

  def csrf_ok?
    return false unless request.params.key?('_csrf')
    return false unless session[:csrf] == request.params['_csrf']
    return false unless request.cookies.key?('authenticity_token')
    return false unless session[:csrf] == request.cookies['authenticity_token']
    true
  end
end
