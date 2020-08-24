module Kukupa::Helpers::FlashHelpers
  def flash(type, message)
    message = message.force_encoding("UTF-8")
    session[:flash] ||= []
    session[:flash] << {:type => type, :message => message}
  end

  def render_flashes
    return "" unless session[:flash].is_a?(Array)

    session.delete(:flash).map do |f|
      haml(:flash, :layout => false, :locals => {
        :type => f[:type].to_s,
        :message => f[:message],
      }).to_s
    end.compact.join("").force_encoding("UTF-8")
  end
end
