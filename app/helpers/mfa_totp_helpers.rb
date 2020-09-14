require 'base64'

module Kukupa::Helpers::MfaTotpHelpers
  def rotp_instance(secret)
    ROTP::TOTP.new(secret, issuer: Kukupa.app_config['site-name'])
  end

  def generate_qr(url)
    qr = RQRCode::QRCode.new(url)
    svg = qr.as_svg({
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 6,
      standalone: true,
    })

    "data:image/svg+xml;base64,#{Base64.encode64(svg)}"
  end
end
