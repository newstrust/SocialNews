class HomeController < ApplicationController
  include LandingStoryListings
  include StoriesHelper

  APP_NAME = SocialNewsConfig["app"]["name"]
  
    # Set up RSS autodiscovery links
  @@radl = Array.new
  @@radl << {:link => "/stories/most_recent.xml", :title => "#{APP_NAME}: Top Stories"}
  @@radl << {:link => "/stories/most_recent/news.xml", :title => "#{APP_NAME}: Top Stories: News"}
  @@radl << {:link => "/stories/most_recent/opinion.xml", :title => "#{APP_NAME}: Top Stories: Opinion"}

    # Randomize the cache times for each segment by upto +/- 10 seconds
  @@staging_area_refresh_time      = SocialNewsConfig["caching"]["refresh_times"]["home_page_staging"]         + (rand(10) - 5)
  @@grid_and_listings_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["home_page_grid_n_listings"] + (rand(10) - 5)
  @@right_column_refresh_time      = SocialNewsConfig["caching"]["refresh_times"]["home_page_right_column"]    + (rand(10) - 5)

  def index
    @url_tracking_key = "hp"
    @has_story_listings = true

      # Cache staging area, news comparison, story grid + listings, and right column separately
    @cached_staging_area      = get_cached_fragment_name("hp_staging_area", nil)
    @cached_grid_and_listings = get_cached_fragment_name("hp_grid_and_listings", nil)
    @cached_right_column      = get_cached_fragment_name("hp_right_column", nil)

      # 1. Staging area with featured story
    listed_story_ids = get_cached_story_ids_and_when_fragment_expired(@cached_staging_area, @@staging_area_refresh_time.seconds) do
      @will_be_cached = true

      # reviews/blocks below the carousel
      staging_constants = LayoutSetting.load_settings_hash(@local_site, nil, "staging")
      @featured_reviews = (1..2).collect { |i| r_id = staging_constants["review_#{i}"].value; !r_id.blank? ? Review.find(r_id) : nil }
      @featured_blocks  = (1..2).collect { |i| b_id = staging_constants["block_#{i}"].value; !b_id.blank? ? EditorialBlock.find_by_slug(b_id) : nil }

      # collect active slides for the carousel and order them according to rank
      @carousel_slides = (LayoutSetting.load_settings(@local_site, nil, "carousel") || {}).collect { |slide|
        slide.unmarshal!
        slide.value if slide.value["active?"]
      }.compact
      @carousel_slides.sort! { |s1, s2| (s1["rank"] || 0) <=> (s2["rank"] || 0) }

      # Last statement in block should yield a flat list of story ids
      @carousel_slides.collect { |s| s["type"] == "story" ? s["story"]["story_id"] : nil }.compact
    end

      # 2. Right hand column
    news_comparison_story_ids = get_cached_story_ids_and_when_fragment_expired(@cached_right_column, @@right_column_refresh_time.seconds) do
      @will_be_cached = true
      @right_column_spaces = EditorialSpace.on_homepage(@local_site).find(:all, :conditions => {:context => "right_column"}, :order => "position ASC")
      ft_setting = LayoutSetting.find_setting(@local_site, nil, "staging", "featured_topic")
      if ft_setting.nil?
        @featured_topic = nil
        ncs = {}
      else
        @featured_topic = Topic.find_topic(ft_setting.value, @local_site)
        ncs = @featured_topic ? load_news_comparison_settings(@local_site, nil, @featured_topic, listed_story_ids) : {}
      end
      @news_comparison_settings = ncs[:settings]
      @news_comparison_stories  = ncs[:stories]
      @news_more_stories_link   = ncs[:more_stories_link]
      @news_more_stories_text   = ncs[:more_stories_text]
      (@news_comparison_stories || []).map(&:id) # Last statement in block should yield a flat list of story ids
    end

      # 3. Story grid + subject listings
    listed_story_ids += news_comparison_story_ids
    grid_and_listing_story_ids = get_cached_story_ids_and_when_fragment_expired(@cached_grid_and_listings, @@grid_and_listings_refresh_time.seconds) do
      gs = load_grid_settings(@local_site, nil, listed_story_ids)
      listed_story_ids = gs[:listed_story_ids]
      @grid_stories = gs[:stories]

      @subj_listings = load_homepage_listings(@local_site, listed_story_ids, :no_local => true)
      @todays_feeds_stories = find_queued_stories(@local_site, {:use_activity_score => true, :paginate => false, :per_page => 5, :max_stories_per_source => LocalSite.max_stories_per_source(@local_site), :listing_type_opts => {:min_score => Feed::TODAYS_FEEDS_MIN_SCORE, :no_pending_sources => true}})

        # Last statement in block must yield a flat list of stories
      @will_be_cached = true
      @subj_listings.collect { |l| l[:stories] }.flatten.map(&:id) + @todays_feeds_stories.map(&:id) + listed_story_ids
    end

    @cached_story_ids = listed_story_ids + grid_and_listing_story_ids
    @rss_autodiscovery_links = @@radl
  end

  def access_denied
    flash[:error] = "Access Denied"
  end
end
