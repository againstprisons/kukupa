require 'memoist'

module Kukupa
  VERSION = "0.1.0-alpha.1"

  class << self
    extend Memoist

    def version
      gitrev = `sh -c 'command -v git >/dev/null && git describe --always --tags --abbrev --dirty'`.strip
      if gitrev != ""
        "v#{VERSION} rev #{gitrev}"
      else
        "v#{VERSION}"
      end
    end

    memoize :version
  end
end
