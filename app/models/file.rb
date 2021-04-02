require 'mimemagic'
require 'digest'

class Kukupa::Models::File < Sequel::Model
  def self.upload(data, opts = {})
    fileid = Kukupa::Crypto.generate_token_long
    while self.where(file_id: fileid).count.positive?
      fileid = Kukupa::Crypto.generate_token_long
    end

    obj = self.new(file_id: fileid, creation: Sequel.function(:NOW)).save
    obj.replace(opts[:filename], data)
    obj.mime_type = opts[:mime_type] if opts[:mime_type]
    obj.save

    obj
  end
  
  def replace(filename, data)
    mime = MimeMagic.by_magic(data)
    unless filename
      filename = "unknown"
      if mime && mime.extensions.count.positive?
        filename = "#{filename}.#{mime.extensions.first}"
      end
    end
    
    # Encrypt file
    encrypted = Kukupa::Crypto.encrypt("file", self.file_id, nil, data)

    # Hash it
    digest = Digest::SHA512.hexdigest(encrypted)

    # Get paths
    dirname = File.join(Kukupa.app_config["file-storage-dir"], digest[0..1])
    filepath = File.join(dirname, digest)
    raise "A duplicate file already exists." if File.exist?(filepath)

    # Create dir to hold file if it doesn't already exist
    Dir.mkdir(dirname) unless Dir.exist?(dirname)

    # Save file
    File.open(filepath, "wb+") do |f|
      f.write(encrypted)
    end
    
    self.file_hash = digest
    self.mime_type = mime
    self.original_fn = filename
  end

  def generate_download_token(user)
    user = user.id if user.respond_to?(:id)

    token = Kukupa::Models::Token.generate_long
    token.expiry = Time.now + (60 * 60) # expire in an hour
    token.user_id = user
    token.use = "file_download"
    token.extra_data = self.file_id
    token.save

    token
  end

  def generate_fn
    partial_id = self.file_id[0..7]
    fn = "kukupa_#{partial_id}_#{self.creation.strftime("%s")}"

    ext = nil
    if self.mime_type
      mime = MimeMagic.new(self.mime_type)
      ext = mime.extensions.first
    end

    ext = "bin" unless ext
    fn += ".#{ext}"

    fn
  end

  def abspath
    digest = self.file_hash
    File.join(Kukupa.app_config["file-storage-dir"], digest[0..1], digest)
  end

  def decrypt_file
    data = File.open(self.abspath, "rb") do |f|
      f.read
    end

    Kukupa::Crypto.decrypt("file", self.file_id, nil, data)
  end

  def delete!
    File.unlink(self.abspath)
    self.delete
  end
end
