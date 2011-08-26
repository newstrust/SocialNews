module ReviewsHelper
  def review_form_options(form_type, curr_version)
    # Rails 2.3 has helpers for doing this, but since we are on Rails 2.1 right now, no good for us!
    # Quick hack to replace Mini by Short for the user.  Later on, we should systematically replace all refs to mini with short
    opts = []
    ["mini", "quick", "full", "advanced"].each { |fl|
      opt_val = "#{form_type}:#{fl}"
      opts << ["<option value='#{opt_val}'#{" selected='selected'" if curr_version==opt_val}>#{fl == "mini" ? "Short" : fl.titlecase} #{form_type.titlecase}</option>"]
    }
    opts * '\n'
  end
  
  def rating_input(options={})
    options[:star_class] ||= ""
    options[:hide_clear_button] ||= false
    options[:criterion] ||= nil # fairly ludicrous syntax here, guys
    options[:form_level] ||= ""
    options[:style] ||= ""
    options[:menu] ||= nil
    render :partial => 'reviews/rating_input', :locals => options
  end
  
  def ratings_box(options={})
    default_options = {
      :use_processed_ratings => false,
      :trustometer_img_options => {},
      :hide_trustometer_message => nil,
      :id => "ratings"
    }
    render :partial => "shared/ratings_box", :locals => default_options.merge(options)
  end
  
  def ratings_box_line(options={})
    default_options = {
      :help_icon => nil,
      :trustometer_img_options => {},
      :heading_class => "",
      :rating_value => nil,
      :integer_rating => false,
      :note => nil,
      :hide_trustometer_message => nil
    }
    render :partial => "shared/ratings_box_line", :locals => default_options.merge(options)
  end
  
  # Link to the toolbar, usually to do a new review.
  # For framebuster sites, this will go to a popup with the salient toolbar forms.
  #
  # Options:
  #   :go - tab of toolbar to automatically open
  #   :cached - true if link is in a cached block!
  #   :class - optional css class
  #   :review_only - DEPRECATED. open review w/o opening story. used only on story edit form.
  #
  def link_to_new_review(story, text="", options={})
    options[:class] ||= "review"
    reviewed = false
    if options[:go] != "share"
			if options[:cached]
				# This will save us an extra db call / story to check for review state
				reviewed = false
				options[:class] += ' review_link' if options[:cached]
			else
				reviewed = story.reviewed_by?(current_member)
				options[:class] += ' on' if reviewed
			end
		end

    # NOTE: copy changes here must be made in application.js as well!!!
    options[:title] = reviewed ? "Edit your review" : (options[:go] || "review").capitalize + " this story"

    if options[:embedded_video_link]
      # route-generation method is very sensitive to that second arg .. so, slice off :go from options
      # If the story is unvetted, take the member to the edit form first!
      options[:go] = story.is_unvetted? ? "edit" : "review" if options[:go].nil? && logged_in?

      link_opts = {:popup => true, :embedded_video => true}
      link_opts.merge!(options.slice(:go)) if options.has_key?(:go)
      link_opts.merge!(options.slice(:ref)) if options.has_key?(:ref) && !options[:ref].blank?
      link_url = toolbar_story_url(story, link_opts)
      link_to(text, "#", options.merge(:onclick => "open_popup('#{link_url}', ''); return false"))
    elsif story.from_framebuster_site? || user_has_ie6? || story.is_pdf?
      options[:go] = "review" if options[:go].nil?

      # route-generation method is very sensitive to that second arg .. so, slice off :go from options
      link_opts = {:popup => true}
      link_opts.merge!(options.slice(:go)) if options.has_key?(:go) && !options[:go].blank?
      link_opts.merge!(options.slice(:ref)) if options.has_key?(:ref) && !options[:ref].blank?
      link_url = toolbar_story_url(story, link_opts)
      link_to(text, story.url, options.merge(:onclick => "return open_popup('#{link_url}', $(this))"))
    else
      options[:go] = story.is_unvetted? ? "edit" : "review" if options[:go].nil? && logged_in?

      # route-generation method is very sensitive to that second arg .. so, slice off :go from options
      link_opts = {}
      link_opts.merge!(options.slice(:go)) if options.has_key?(:go) && !options[:go].blank?
      link_opts.merge!(options.slice(:ref)) if options.has_key?(:ref) && !options[:ref].blank?
      rp = link_opts.blank? ? toolbar_story_path(story) : toolbar_story_path(story, link_opts)
      options[:target] = "_blank" # always open toolbar links in a new window
      link_to(text, rp, options)
    end
  end

  alias :link_to_toolbar :link_to_new_review
  
  def link_to_in_popup(text, route)
    link_to_function(text, "Popup.open('#{url_for(route)}')")
  end
  
  
  # Ratings, Stars, Trustometers
  #
  
  # to be used in place of full-granularity trustometer in widgets & emails
  # and anywhere else where our CSS tricks are liable not to work.
  # Options:
  # :size in [:small, :large]
  # :color in [:green]
  def static_trustometer_img(rating, options={})
    img_path = [(options[:absolute_path] ? home_url : "")]
    img_path << "images/trustometer"
    img_path << (options[:size] || :small).to_s
    img_path << options[:color].to_s if options[:color]
    return rating_image_tag(rating, img_path, {}, {:border => 0})
  end

  # for legacy-style stars, squares, bullets
  def static_rating_img(rating, options={}, html_options={})
    rating_img_path = ["/images/stars"]
    rating_img_path << options[:shape].to_s.pluralize if options[:shape]
    rating_img_path << options[:color].to_s if options[:color]
    rating_img_path << options[:size].to_s if options[:size]
    return rating_image_tag(rating, rating_img_path, options, html_options)
  end

  def rating_image_tag(rating, rating_img_path, options={}, html_options={})
    rating ||= 0 # ?
    options[:rating_title] ||= " avg."
    options[:rating_accuracy] ||= 10.0
    rating_img_path << ((rating*2).round / 2.0).to_s.gsub(/\./, "-") + ".gif"
    img_title = ((rating*options[:rating_accuracy]).round / options[:rating_accuracy]).to_s + options[:rating_title]
    return image_tag(rating_img_path.compact.join("/"), html_options.merge(:alt => img_title, :title => img_title))
  end

  # Options:
  # :size in [:small, :medium, :large]
  # :color in [:yellow, :yellowgray, :gray, :green]
  def trustometer_img(rating, options={}, html_options={})
    return static_rating_img(rating, options, html_options) if options[:shape]
    rating ||= 0 # ?
    options[:size] ||= :medium
    options[:color] ||= :green
    options[:group] ||= nil
    options[:num_rating_class] ||= :numeric_rating
    width = ((rating.to_f / 5) * 100).to_i
    return content_tag_sane(:div, html_options.merge(:class => "trustometer#{options[:group] ? " group" : ""}"),
      content_tag_sane(:div, {:class => "#{options[:size]} #{options[:color]}"},
        content_tag_sane(:div, {:class => "bar"},
          content_tag_sane(:div, {:style => "width: #{width}%"})) +
        content_tag_sane(:div, {:class => "#{options[:num_rating_class]}"}, format_rating(rating))))
  end
  
  # b/c the syntax of the rails method is making me nuts
  def content_tag_sane(tag, options, content="")
    content_tag(tag, content, options)
  end
  
  # one place past decimal
  def format_rating(rating)
    if rating
      "%.1f" % rating
    else
      "0"
    end
  end
  
  def adjectival_rating(rating)
    rating ? SocialNewsConfig["rating_labels"][rating.round-1] : "no rating"
  end
  
  # percentigize 0-5 float
  def confidence_rating(processable)
    processable.processed_rating("confidence") ? "%.f" % (processable.processed_rating("confidence") * 100) + "%" : "not calculated"
  end
end
