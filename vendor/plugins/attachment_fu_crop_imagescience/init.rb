Geometry.module_eval do
  
  FLAGS = ['', '%', '<', '>', '!']#, '@']
  
  def to_s
    str = ''
    str << "%g" % @width if @width > 0
    str << 'x' if (@width > 0 || @height > 0)
    str << "%g" % @height if @height > 0
    str << "%+d%+d" % [@x, @y] if (@x != 0 || @y != 0)
    str << RFLAGS.index(@flag)
  end
  
  # attempts to get new dimensions for the current geometry string given these old dimensions.
  # This doesn't implement the aspect flag (!) or the area flag (@).  PDI
  def new_dimensions_for(orig_width, orig_height)
    new_width  = orig_width
    new_height = orig_height

    case @flag
      when :percent
        scale_x = @width.zero?  ? 100 : @width
        scale_y = @height.zero? ? @width : @height
        new_width    = scale_x.to_f * (orig_width.to_f  / 100.0)
        new_height   = scale_y.to_f * (orig_height.to_f / 100.0)
      when :<, :>, nil
        scale_factor =
          if new_width.zero? || new_height.zero?
            1.0
          else
            if @width.nonzero? && @height.nonzero?
              [@width.to_f / new_width.to_f, @height.to_f / new_height.to_f].min
            else
              @width.nonzero? ? (@width.to_f / new_width.to_f) : (@height.to_f / new_height.to_f)
            end
          end
        new_width  = scale_factor * new_width.to_f
        new_height = scale_factor * new_height.to_f
        new_width  = orig_width  if @flag && orig_width.send(@flag,  new_width)
        new_height = orig_height if @flag && orig_height.send(@flag, new_height)
      when :aspect
        new_width = @width unless @width.nil?
        new_height = @height unless @height.nil?
    end

    [new_width, new_height].collect! { |v| v.round }
  end
  
end

Technoweenie::AttachmentFu::Processors::ImageScienceProcessor.module_eval do

  def resize_image(img, size)
    # create a dummy temp file to write to
    self.temp_path = write_to_temp_file(filename)
    grab_dimensions = lambda do |img|
      self.width  = img.width  if respond_to?(:width)
      self.height = img.height if respond_to?(:height)
      img.save temp_path
      self.size = File.size(self.temp_path)
      callback_with_args :after_resize, img
    end
    size = size.first if size.is_a?(Array) && size.length == 1
    if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
      if size.is_a?(Fixnum)
        img.thumbnail(size, &grab_dimensions)
      else
        img.resize(size[0], size[1], &grab_dimensions)
      end
    else
      n_size = [img.width, img.height] / size.to_s
      if size.ends_with? "!"
        aspect = n_size[0].to_f / n_size[1].to_f
        ih, iw = img.height, img.width
        w, h = (ih * aspect), (iw / aspect)
        w = [iw, w].min.to_i
        h = [ih, h].min.to_i
        img.with_crop( (iw-w)/2, (ih-h)/2, (iw+w)/2, (ih+h)/2) {
          |crop| crop.resize(n_size[0], n_size[1], &grab_dimensions )
        }
      else
        img.resize(n_size[0], n_size[1], &grab_dimensions)
      end
    end
  end

end