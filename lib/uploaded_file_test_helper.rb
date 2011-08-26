module UploadedFileTestHelper
  def uploaded_file(path, content_type="application/octet-stream", filename=nil)
    filename ||= File.basename(path)
    t = Tempfile.new(filename)
    FileUtils.copy_file(path, t.path)
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end
  
  # A JPEG helper
  def uploaded_jpeg(path, filename = nil)
    uploaded_file(path, 'image/jpeg', filename)
  end

  # A TXT helper
  def uploaded_txt(path, filename = nil)
    uploaded_file(path, 'text/plain', filename)
  end
end