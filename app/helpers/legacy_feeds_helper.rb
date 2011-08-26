module LegacyFeedsHelper

  include StoriesHelper

  def get_feed_data(feed_name, feed_category, num_stories)
    return get_feed_data_by_media_type(feed_name, num_stories) if (feed_category && feed_category == "media")

    is_toplevel_feed = feed_category.nil?
    feed_params      = get_feed_params(feed_name)
    topic_slug       = feed_params[:t_slug]

      # If this is a request for the top-level rssfeed (most_trusted, for_review, recent_reviews)
      # topic_slug should be null!  If not, this is a bad request!
    raise "Unsupported url" if (is_toplevel_feed && !topic_slug.blank?)

      # Update t_slug and s_slug values, compute listing url, and the listing topic
    feed_params[:t_slug]        = (feed_category == "topics") ? topic_slug : nil
    feed_params[:s_slug]        = (feed_category == "subjects") ? topic_slug : nil
    feed_params[:listing_url]   = url_for feed_params.merge({:controller => "stories", :action  => "index"})
    feed_params[:listing_topic] = topic_slug.blank? ? "" : (Topic.slug_is_subject(topic_slug) ? Topic.get_subject_name_from_slug(topic_slug) \
                                                                                              : Topic.find_topic(topic_slug, @local_site).name)
    feed_params[:local_site]    = @local_site ? @local_site.name.downcase : nil
    return { 
      :feed_params => feed_params,
      :items       => Story.normalize_opts_and_list_stories(@local_site, feed_params.merge(:fill_story_window => true, :per_page => num_stories))
    }
  end

  MEDIA_TYPES = { "blogs"        => SourceMedium::BLOG,
                  "tv"           => SourceMedium::TV,
                  "radio"        => SourceMedium::RADIO,
                  "newspapers"   => SourceMedium::NEWSPAPER,
                  "magazines"    => SourceMedium::MAGAZINE,
                  "online"       => SourceMedium::ONLINE,
                  "wireservices" => SourceMedium::WIRE }

  def get_feed_data_by_media_type(feed_name, num_stories)
    media_type = MEDIA_TYPES[feed_name]
    stories = Story.list_stories(:listing_type => :most_recent, 
                                 :start_date => 1.month.ago, 
                                 :filters => {:local_site => @local_site, :sources => {:media_type => media_type}}, 
                                 :per_page => num_stories)
    return { :feed_params => { 
                 :t_slug           => "",
                 :listing_type     => "",
                 :story_type       => "",
                 :source_ownership => "",
                 :listing_url      => url_for({ :controller => "stories", :action  => "index", :sources => {:media_type => media_type} }),
                 :listing_topic    => media_type == "tv" ? "TV" : media_type.capitalize
             },
             :items => stories }
  end

  # 'url' will be of the form below. Extract information about of it
  #   election_reform
  #   election_reform_ind     (or _msm)
  #   election_reform_opinion (or _news)
  #   election_reform_opinion_ind
  #   election_reform_most_trusted
  #   election_reform_most_trusted_ind
  #   election_reform_most_trusted_opinion
  #   election_reform_most_trusted_opinion_ind; 
  #   election_reform_for_review 
  #   election_reform_recent_reviews 
  def get_feed_params(feed_name)
    listing_type = ""
    listing_type = $1 if (feed_name =~ /(most_trusted)/);
    listing_type = $1 if (feed_name =~ /(most_recent)/);
    listing_type = "for_review"     if (feed_name =~ /for_review/);
    listing_type = "recent_reviews" if (feed_name =~ /recent_reviews/);

    story_type       = (feed_name =~ /_news/) ? "news" : ((feed_name =~ /_opinion/) ? "opinion" : "")
    source_ownership = (feed_name =~ /_msm/)  ? Source::MSM : ((feed_name =~ /_ind/) ? Source::IND : "")

      ## Remove all name components that we've already analyzed
    tmp = feed_name
    tmp.sub!(/_#{source_ownership}$/, '') if source_ownership != ""
    tmp.sub!(/_#{story_type}$/, '') if story_type != ""
    tmp.sub!(/_#{listing_type}$/, '') if listing_type != ""

      ## Set the 'most_recent' listing type value after the replacements above because of how feeds are named
      ## 'most_recent' string is not present except for site-level story listings ... in all those cases, this
      ## listing type is implicitly assumed
    orig_listing_type = listing_type
    listing_type = "most_recent"  if listing_type.blank?

      # 1. If we are left with just the listing type, there is no topic/subject ... we are fetching site-level story listings
    { 
      :t_slug           => (tmp == orig_listing_type) ? nil : tmp,
      :listing_type     => listing_type,
      :story_type       => (story_type == "")       ? nil : story_type, 
      :source_ownership => (source_ownership == "") ? nil : Source::OWNERSHIP[source_ownership].downcase
    }
  end
end
