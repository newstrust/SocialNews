module HomeHelper

  def rss_icon_tag(html_options={})
    image_tag('/images/ui/rss-12x12.jpg', html_options.merge(:size => "12x12", :alt => "RSS Feed"))
  end
  
  # feed links
  def rss_icon(options, html_options={})
    return rss_link(image_tag('/images/ui/rss-12x12.jpg', html_options.merge(:size => "12x12", :alt => "RSS Feed")), options, html_options)
  end

  def rss_link(text, options, html_options={})
    return link_to(text, url_for(options.merge(:controller => :stories, :format => :xml)))
  end
  
end
