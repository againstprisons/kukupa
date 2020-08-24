module Kukupa::Utils
  # Converts a CamelCaseName to a snake_case_name.
  #
  # Taken from https://stackoverflow.com/a/1509939
  def self.camel_case_to_snake_case(name)
    name
      .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      .gsub(/([a-z\d])([A-Z])/,'\1_\2')
      .tr("-", "_")
      .downcase
  end

  # Turns a string of hexadecimal characters into it's binary representation.
  def self.hex_to_bin(data)
    return "" if data.nil?
    return data.scan(/../).map do |x|
      x.hex.chr
    end.join.encode(Encoding::BINARY)
  end

  # Turns a binary-encoded string into it's hexadecimal representation.
  def self.bin_to_hex(data)
    return "" if data.nil?
    return data.each_byte.map do |b|
      t = b.to_s(16)
      t = "0" + t if t.length == 1
      t
    end.join.encode(Encoding::BINARY)
  end
end
