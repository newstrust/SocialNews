namespace :socialnews do
  def add_new_image(m, img, thumbnail, filename)
    i = Image.find(:first, :conditions => {:parent_id => m.image.id, :thumbnail => thumbnail})
    if i.nil?
      basename = filename.gsub(%r|.*/|, '')
      Image.create(:filename => basename, :parent_id => m.image.id, :thumbnail => thumbnail, :size => File.stat(filename).size, :width => img.width, :height => img.height, :content_type => m.image.content_type)
      puts "created new entry in the db for resized image: #{filename}"
    else
      puts "resized image already exists in the db!"
    end
  end

  def save_resized_img(m, img, thumb_name, img_file_path)
    fn = img_file_path.gsub(%r{(.*)\.(jpg|png|gif)}i, '\1_' + thumb_name + '.\2')
    img.save(fn)
    add_new_image(m, img, thumb_name, fn)
  end

  def create_thumbnail(m, img, thumb_name, s, img_file_path)
    puts "Resizing to #{s}x#{s}"
    img.cropped_thumbnail(s) { |i| save_resized_img(m, i, thumb_name, img_file_path) }
  end

  def create_resized_img(m, img, thumb_name, max_w, max_h, img_file_path)
    w = img.width
    h = img.height

      # No resizing if the uploaded image is smaller than what we want
    if (w <= max_w) && (h <= max_h)
       save_resized_img(m, img, thumb_name, img_file_path)
    else
        # Resize width first
      h = max_w * h/w
      w = max_w

        # If height has overshot, resize one more time 
      if (h > max_h)
        w = max_h * w/h
        h = max_h
      end

      puts "Resizing to #{w}x#{h}"
      img.resize(w, h) { |i| save_resized_img(m, i, thumb_name, img_file_path) }
    end
  end

  desc "Resize member photos"
  task(:resize_member_photos => :environment) do
    Member.find(:all, :select => "id").each do |m|
      begin
        m = Member.find(m.id)
        puts "Processing member #{m.id}:#{m.name}"
        if m.image
          i_fn = "public#{m.image.public_filename}"
          ImageScience.with_image(i_fn) do |img|
            create_thumbnail(m, img, "favicon", 18, i_fn)
            create_thumbnail(m, img, "small_thumb", 30, i_fn)
            create_resized_img(m, img, "medium", 100, 125, i_fn)
            create_resized_img(m, img, "large", 200, 250, i_fn)
          end
          puts " ... look for images with similar filenames as #{i_fn} (with _favicon, _small_thumb, _medium, and _large in filename)"
        else
          puts " ... skipping since there is no existing image to resize"
        end
      rescue Exception => e
        puts "Exception resizing member photos for member #{m.name} with image path: public#{m.image.public_filename}"
      end
    end
  end

  desc "Resize topic/subject photos"
  task(:resize_topic_photos => :environment) do
    Topic.find(:all, :select => "id").each do |t|
      begin
        topic = Topic.find(t.id)
        puts "Processing topic #{topic.id}:#{topic.name}"
        if topic.image
          i_fn = "public#{topic.image.public_filename}"
          ImageScience.with_image(i_fn) do |img|
            create_thumbnail(topic, img, "favicon", 18, i_fn)
          end
          puts " ... look for images with similar filenames as #{i_fn} (with _favicon in filename)"
        else
          puts " ... skipping since there is no existing image to resize"
        end
      rescue Exception => e
        puts "Exception resizing photos for topic #{topic.name} with image path: public#{topic.image.public_filename}"
      end
    end
  end
end
