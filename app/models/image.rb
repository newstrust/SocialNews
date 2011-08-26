class Image < ActiveRecord::Base
  BASE_PATH = "images/photos"

  belongs_to :imageable, :polymorphic => true
  has_attachment :path_prefix  => (ATTACHMENT_FU_OPTIONS[:basepath_prefix] || "") + BASE_PATH,
                 :storage      => (ATTACHMENT_FU_OPTIONS[:storage] || :s3),
                 :content_type => :image,
                 :max_size     => 550.kilobyte, # Limit image uploads to 550 kb (50kb slop even though we say, max 500kb in the UI)
                    # small_thumb is used on search results page 
                    # thumb, medium, large are used on member profiles
                    # thumb, column are used on topic pages 
                 :thumbnails   => { :favicon     => '18x18!', 
                                    :small_thumb => '30x30!', 
                                    :thumb       => '40x40!', 
                                    :medium      => '100x125>', 
                                    :column      => '235x235>', 
                                    :large       => '200x250>' },
                 :processor    => "ImageScience"
  validates_as_attachment

      # Download the image, etc.
  def self.download_from_url(pic_url)
    return nil if pic_url.nil?

    uri  = URI.parse(pic_url)
    resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(Net::HTTP::Get.new(uri.path)) }
    case resp
      when Net::HTTPSuccess then
          # The image is being processed as an attachment => download the image into the tmp directory
          # since the attachment processing will copy it over to wherever it needs to be.  
          # No use littering up the public/images/photos/ directory with temporary images.
        base_dir = "tmp/"
        filename = File.join(base_dir, pic_url.gsub(/.*\//, '')) # Where to save the file!
        File.open(filename, "w") { |fh| fh.write(resp.body) } # Save the image!
        w,h = 0,0
        ImageScience.with_image(filename) { |i| w, h = i.width, i.height }
        i = Image.new(:filename => filename, :size => resp['content-length'], :width => w, :height => h, :content_type => resp['content-type'])
            # Set the downloaded path as the temp file name and the attachment processing code
            # will process this file as an uploaded attachment!
        i.temp_path = filename  
        return i
      else
        logger.error "Got #{resp} while downloading #{pic_url}"
    end
    resp
  rescue Exception => e
     logger.error "Exception #{e} while downloading image from url #{pic_url}!"
     return nil
  end
end
