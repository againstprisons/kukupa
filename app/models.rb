class Sequel::Model
  def _encrypt_table_name
    self.class.name.split("::").last.downcase
  end

  def decrypt(field)
    data = self.send(field.to_sym)
    return Kukupa::Crypto.decrypt(self._encrypt_table_name, field.to_s, self.id.to_s, data).to_s
  end

  def encrypt(field, data)
    encrypted = Kukupa::Crypto.encrypt(self._encrypt_table_name, field.to_s, self.id.to_s, data.to_s)
    self.send(:"#{field.to_s}=", encrypted)
  end
end

module Kukupa::Models
  def self.load_models
    Dir.glob(File.join(Kukupa.root, 'app', 'models', '*.rb')).each do |f|
      require f
    end
  end
end
