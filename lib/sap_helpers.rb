module SapHelpers
      ## Assuming that urls from these domains are blog posts!
  BLOG_DOMAINS = [ "blogspot.com", "blogger.com", "livejournal.com", "wordpress.com" ]

      ## Advertisements!
  AD_DOMAINS = ["ads.pheedo.com", "pub.vitrue.com"]

      ## Aggregator domains
  AGGREGATOR_DOMAINS = [ "digg.com", "memeorandum.com", "google.com", "youtube.com", "stumbleupon.com",
                         "fairspin.org", "daylife.com", "muckrack.com", "ginx.com" ]

  def is_aggregator_domain?(d)
    !(AGGREGATOR_DOMAINS.find { |p| d =~ /#{p}/ }).nil?
  end

  def is_blog_domain?(d)
    !(BLOG_DOMAINS.find { |p| d =~ /#{p}/ }).nil?
  end

  def is_ad_domain?(d)
    AD_DOMAINS.include?(d)
  end

  def ad_image_or_ignoreable?(url)
    !(url =~ /\.(jpg|gif|png|bmp|mov|tiff|tif|pdf|doc|xls|ppt)$/).nil? || is_ad_domain?(NetHelpers.get_url_domain(url))
  end
end
