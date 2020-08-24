require 'mimemagic'

class Kukupa::Controllers::StaticController < Kukupa::Controllers::ApplicationController
  VENDOR_WHITELIST = [
    "/purecss/build",
    "/font-awesome/css",
    "/font-awesome/fonts",
  ]

  add_route :get, "/css/:name.css", :method => :css
  add_route :get, "/vendor/*", :method => :vendor
  add_route :get, "/*"

  def before
    settings.views = {
      :scss => File.join("assets", "scss"),
      :default => File.join("app", "views"),
    }
  end

  def css(name)
    style = :compressed
    style = :nested if settings.development?

    content_type 'text/css'
    scss name.to_sym, :style => style
  end

  def vendor(splat)
    fn = File.expand_path(splat, "/")
    path = File.join(Kukupa.root, "node_modules", fn)

    # vendor whitelist check
    return halt 404, "" unless VENDOR_WHITELIST.map{|x| fn.start_with?(x)}.any?

    return halt 404, "" unless File.file? path
    content_type MimeMagic.by_path(path)
    send_file path
  end

  def index(splat)
    fn = File.expand_path(splat, "/")
    path = File.join(Kukupa.root, "public", fn)

    if Kukupa.theme_dir
      themepath = File.join(Kukupa.theme_dir, "public", fn)
      path = themepath if File.file? themepath
    end

    return halt 404, "" unless File.file? path
    content_type MimeMagic.by_path(path)
    send_file path
  end
end
