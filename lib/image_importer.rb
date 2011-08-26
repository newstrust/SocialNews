#
# Tool for spoon-feeding images into attachment_fu.
# Only used by the legacy_data:refresh_images task,
# but could eventually be expanded/modified to grab images
# from other sites if we so desired.
#
#

require 'tempfile'

class ImageImporter
  
  # this is so we can fake out attachment_fu & spoon-feed it local files
  # see: http://benr75.com/articles/2008/01/04/attachment_fu-now-with-local-file-fu
  class LocalFile
    # The filename, *not* including the path, of the "uploaded" file
    attr_reader :original_filename
    # The content type of the "uploaded" file
    attr_reader :content_type

    def initialize(path)
      raise "#{path} file does not exist" unless File.exist?(path)
      content_type ||= @@image_mime_types[File.extname(path).downcase]
      raise "Unrecognized MIME type for #{path}" unless content_type
      @content_type = content_type
      @original_filename = File.basename(path)
      @tempfile = Tempfile.new(@original_filename)
      FileUtils.copy_file(path, @tempfile.path)
    end

    def path #:nodoc:
      @tempfile.path
    end
    alias local_path path

    def method_missing(method_name, *args, &block) #:nodoc:
      @tempfile.send(method_name, *args, &block)
    end

    @@image_mime_types ||= { ".gif" => "image/gif", ".ief" => "image/ief", ".jpe" => "image/jpeg", ".jpeg" => "image/jpeg", ".jpg" => "image/jpeg", ".pbm" => "image/x-portable-bitmap", ".pgm" => "image/x-portable-graymap", ".png" => "image/png", ".pnm" => "image/x-portable-anymap", ".ppm" => "image/x-portable-pixmap", ".ras" => "image/cmu-raster", ".rgb" => "image/x-rgb", ".tif" => "image/tiff", ".tiff" => "image/tiff", ".xbm" => "image/x-xbitmap", ".xpm" => "image/x-xpixmap", ".xwd" => "image/x-xwindowdump" }.freeze 
  end
  
  def self.import_images_from_hash(image_data)
    tmp_dir = "tmp/"
    
    puts "Deleting old images..."
    `rm -rf public/images/photos/*`
    
    puts "Downloading #{image_data.length} images..."
    image_data.each do |url, params|
      file_name = url.split("/").last
      if (file_name =~ /\./).nil? # filename has no dot, assume it's invalid
        file_name = "member_photo.jpg"
      end
      tmp_file_path = tmp_dir + file_name
      
      `curl -s -o "#{tmp_file_path}" "#{url}"`
      
      Image.create(params.merge(:uploaded_data => LocalFile.new(tmp_file_path)))
      
      File.delete(tmp_file_path)
    end
  end
  
end
