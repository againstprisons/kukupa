require 'dotenv/load'

rackup DefaultRackup
env = ENV['RACK_ENV'] || 'development'
environment env

workers Integer(ENV['WEB_CONCURRENCY'] || 2) unless env == 'development'

if env == 'development'
  cert_path = File.expand_path('../certs', __FILE__)
  localhost_crt = File.join(cert_path, 'localhost.crt')
  localhost_key = File.join(cert_path, 'localhost.key')

  unless File.exist? localhost_crt
    def generate_cert(key)
      crt = OpenSSL::X509::Certificate.new
      crt.version = 2
      crt.serial = rand(1000000000)
      crt.subject = OpenSSL::X509::Name.parse '/C=A/O=A/OU=A/CN=localhost'
      crt.issuer = crt.subject
      crt.public_key = key.public_key
      crt.not_before = Time.now
      crt.not_after = crt.not_before + (365 * 24 * 60 * 60) # 1 year
      crt.sign key, OpenSSL::Digest::SHA256.new
      crt
    end

    key = OpenSSL::PKey::RSA.new 2048
    key_fh = File.new(localhost_key, 'wb')
    key_fh.write(key)
    key_fh.close

    crt = generate_cert(key)
    crt_fh = File.new(localhost_crt, 'wb')
    crt_fh.write(crt)
    crt_fh.close
  end

  ssl_bind '0.0.0.0', ENV['PORT'] ||= '9292', key: localhost_key, cert: localhost_crt
else
  port ENV['PORT'] ||= '9292', '0.0.0.0'
end
