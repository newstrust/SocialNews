class FeedsController < ApplicationController
  include StoriesHelper

  protect_from_forgery :except => [ :feed_fetch_status ]

    # Conditionally cache JSON
  caches_page :show, :if => Proc.new { |c| c.request.format.js? || c.request.format.json? }
  caches_page :todays_feeds, :if => Proc.new { |c| c.request.format.js? || c.request.format.json? }

  @@feedpages_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["feed_pages"]
  @@todays_feeds_body_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["todays_feeds_body"]
  @@todays_feeds_sidebar_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["todays_feeds_sidebar"]

  def index
    @feeds = Feed.find(:all, :conditions => Feed.regular_feeds_finder_condition, :order => "name asc")
  end

  def show
    @feed = Feed.find(params[:id])
    # Only admins and feed owners have access to facebook and twitter feeds
    render_404 and return if @feed.is_private? && (!logged_in? || (!current_member.has_role?("admin") && current_member.id != @feed.member_profile_id))

    @url_tracking_key = "fp"
    @has_story_listings = true

    @member = Member.find(@feed.member_profile_id) if @feed.member_profile_id
    respond_to do |format|
      format.html { output_show_html }
      format.json { output_show_json }
      format.js   { output_show_json }
    end
  end

  def ajax_stories
    @feed = Feed.find(params[:id])
    # Only admins and feed owners have access to facebook and twitter feeds
    render_404 and return if @feed.is_private? && (!logged_in? || (!current_member.has_role?("admin") && current_member.id != @feed.member_profile_id))

    listing_type = params[:listing_type].to_sym
    @url_tracking_key = "fp"
    @has_story_listings = true
    @is_ajax_listing = true
    @cached_listing_fragment_name = get_cached_fragment_name(nil, "feeds_listing_#{listing_type.to_s}")
    @cached_story_ids = get_listing(@cached_listing_fragment_name, listing_type)
    render :partial => "feeds/listing", :locals => {:listing_type => listing_type}
  end

  def todays_feeds
    respond_to do |format|
      format.html { output_todays_feeds_html }
      format.json { output_todays_feeds_json }
      format.js   { output_todays_feeds_json }
    end
  end

  def all
    @feeds = Feed.find(:all, :conditions => Feed.regular_feeds_finder_condition, :order => "name asc")

    respond_to do |format|
      format.html do render :layout => (params[:popup] ? "popup" : nil) end
    end
  end

  def num_completed_feeds
    ## Protect against accidental posts from unverified sources
    render_404 and return unless params[:api_key] == FeedParser::FF_KEY

    n = PersistentKeyValuePair.count(:conditions => ["persistent_key_value_pairs.key like ?", "feed.%.status"])
    render :inline => "#{n}", :status => "200"
  end

  def feed_fetch_status
    ## Protect against accidental posts from unverified sources
    logger.error "bad api key: #{params[:api_key]}!" and render_404 and return unless params[:api_key] == FeedParser::FF_KEY

    f = Feed.find(params[:feed_id])
    f.last_fetched_at = params[:end_time]
    f.last_fetched_by = Member.nt_bot.id
    if params[:success] == "true"
      f.success_count ||= 0
      f.success_count += 1
    else
      # If we are a facebook news feed, and our permissions have expired, clear out our extended
      # permissions so that the user can be prompted next time they visit their mynews page ....
      # and/or, we can send them this info as part of their email.
      #
      # SSS FIXME: This really should happen in a background job -- but we are expecting these
      # events to be rare!  So, punt for now!
      if f.is_fb_user_newsfeed? && !f.can_read_fb_newsfeed?
        m = Member.find(f.member_profile_id)
        m.facebook_connect_settings.update_attributes({:ep_read_stream => 0, :ep_offline_access => 0})
      end
      f.failure_count ||= 0
      f.failure_count += 1
    end
    f.save

    # Add an entry into the key value pair db -- basically use the db as a synchronization
    # and communication mechanism between the different feed fetcher ruby scripts and the
    # spawner.  The spawner periodically inspects the db to check if all feeds have completed.
    PersistentKeyValuePair.create(:key => "feed.#{f.id}.status", :value => params[:error])
    render :nothing => true, :status => "200"
  rescue Exception => e
    logger.error "Exception updating feed fetch status. Params: #{params.inspect}. Exception: #{e}; Backtrace:\n#{e.backtrace.inspect}"
    render_404 and return
  end

  private

  def output_show_json
    opts = {
      :feed_id => @feed.id, 
      :paginate => false, 
      :page => 1, 
      :per_page => SocialNewsConfig["widgets"]["stories_per_widget"],
      :timespan => 7, # No need to rely on local site info here -- because feeds are not site-dependent
      :story_status => [Story::FEATURE, Story::LIST, Story::QUEUE, Story::PENDING],
      :listing_type_opts => {:min_score => @local_site ? nil : Feed::TODAYS_FEEDS_MIN_SCORE}
    }
    stories = find_queued_stories(@local_site, opts)  # All status okay
    widget_params = {
      :listing_url  => request.url.sub(/.json$/, ''),
      :source_name  => @feed.name,
      :listing_type => "most_recent"
    }
    widget = widgetize_listing(widget_params, stories)
    @metadata = widget[:metadata]
    @stories  = widget[:stories]
    render :layout => false, :template => "widgets/widgets.json.erb"
  end

  def output_show_html
    @cached_top_area_fragment_name = get_cached_fragment_name(nil, "feeds_top_area")
    when_fragment_expired(@cached_top_area_fragment_name, @@feedpages_refresh_time.seconds.from_now) {}

    @avg_feed_rating  = AggregateStatistic.find_statistic(@feed, "avg_feed_rating")
    @num_feed_stories = AggregateStatistic.find_statistic(@feed, "num_trusted_feed_stories")

    @init_listing_type = :most_recent
    @cached_listing_fragment_name = get_cached_fragment_name(nil, "feeds_listing")
    @cached_story_ids = get_listing(@cached_listing_fragment_name, :most_recent)

      # Use different cached fragments for the main body and the feeds sidebar
      # This way, the sidebar can be reused across feeds and across todays feeds pages
    setup_active_feeds_sidebar
  end

  def get_listing(cached_listing_fragment_name, listing_type)
    @num_days = 30
    get_cached_story_ids_and_when_fragment_expired(cached_listing_fragment_name, @@feedpages_refresh_time.seconds) do
      # For timespans, no need to rely on local site info here -- because feeds are not site-dependent
      opts = { :feed_id => @feed.id, :paginate => false, :page => 1, :per_page => 25, :timespan => @num_days }
      stories = case listing_type
        # No listing constraints on a local site because the auto-fetch scoring algorithm is tuned to national / widely-shared stories
        when :most_popular
          find_queued_stories(@local_site, opts.merge({:story_status      => [Story::FEATURE, Story::LIST, Story::QUEUE], 
                                                       :listing_type_opts => {:min_score => @local_site ? nil : Feed::TODAYS_FEEDS_MIN_SCORE}}))
        when :most_recent
          find_queued_stories(@local_site, opts.merge({:story_status      => [Story::FEATURE, Story::LIST, Story::QUEUE, Story::PENDING],
                                                       :listing_type_opts => {:min_score => @local_site ? nil : Feed::TODAYS_FEEDS_MIN_SCORE}}))
        when :most_trusted 
          Story.normalize_opts_and_list_stories_with_associations(@local_site, opts.merge({:listing_type => :most_trusted, :timespan => 28 }))
      end
      @stories = { listing_type => stories }

        # Last statement in block should yield a flat list of stories
      @will_be_cached = true
      @stories.values.flatten.map(&:id)
    end
  end

  def todays_feeds_stories(num_stories=25, max_stories_per_source=nil)
    # We cannot modify the original params hash -- so clone it, but use syms since story listing code expects symbols, not strings, for keys
    opts = {}; params.each { |k,v| opts[k.to_sym] = v }
    tag = nil
    if params[:ts_slug]
      begin
        slug = opts.delete(:ts_slug)
        topic = Topic.find_topic(slug, @local_site)
        if !topic
          tag = nil
        elsif topic.class == Subject
          opts[:s_slug] = slug
        else
          opts[:t_slug] = slug
        end
      rescue
        logger.error "Ignoring invalid param for todays_feeds: #{slug}"
      end
    end

    if tag
      @subtitle = tag.name

        # Fetch the best 25 stories for the requested topic/subject
        # If we are implementing max-stories-per-source filter, no pagination is available!
      opts.merge!({:use_activity_score => true, :paginate => max_stories_per_source.nil?, :per_page => num_stories, :max_stories_per_source => max_stories_per_source, :listing_type_opts => {:min_score => @local_site ? nil : Feed::TODAYS_FEEDS_MIN_SCORE}})
      @stories = find_queued_stories(@local_site, opts)
      cached_stories = @stories
    else
      @subtitle = "Top Stories"

        # For todays feed used on home page (tag is nil), we always enforce the source diversity filter
      opts.merge!({:use_activity_score => true, :paginate => false, :per_page => num_stories, :max_stories_per_source => 1, :listing_type_opts => {:min_score => @local_site ? nil: Feed::TODAYS_FEEDS_MIN_SCORE, :no_pending_sources => true}})
      @msm_stories = find_queued_stories(@local_site, opts.merge!({:source_ownership => "msm"}))
      @ind_stories = find_queued_stories(@local_site, opts.merge!({:source_ownership => "ind", :exclude_stories => @msm_stories.map(&:id)}))
      cached_stories = @msm_stories + @ind_stories
    end
  end

  def output_todays_feeds_json
    # For today's feeds widgets, Fab wants at most 1 story per source
    stories = todays_feeds_stories(10, 1)
    widget_params = {
      :listing_url   => request.url.sub(/.json$/, ''),
      :listing_topic => @subtitle,
      :listing_type  => "most_recent"
    }
    widget = widgetize_listing(widget_params, stories, false, true)
    @metadata = widget[:metadata]
    @stories  = widget[:stories]
    render :layout => false, :template => "widgets/widgets.json.erb"
  end

  def output_todays_feeds_html
    @url_tracking_key = "sf"
    @has_story_listings = true
    @cached_fragment_name = get_cached_fragment_name(nil, "todays_feeds")
    @cached_story_ids = get_cached_story_ids_and_when_fragment_expired(@cached_fragment_name, @@todays_feeds_body_refresh_time.seconds) do
        # Last statement in block should yield a flat list of stories that are displayed on the target page
      num_stories = params[:ts_slug] && Topic.exists?(:local_site_id => @local_site ? @local_site.id : nil, :slug => params[:ts_slug]) ? 25 : 15
      cached_stories = todays_feeds_stories(num_stories)
      cached_stories.map(&:id)
    end

      # Use different cached fragments for the main body, topics sidebar, and feeds sidebar
      # This way, the sidebar can be reused across subjects, topics, and feeds
    setup_active_topics_sidebar
    setup_active_feeds_sidebar
  end

  def setup_active_topics_sidebar
    @cached_topics_sidebar = "#{@local_site ? @local_site.slug + ':' : ''}todays_feeds_topics_sidebar" + (params[:timespan].blank? ? "" : "__ts=#{params[:timespan]}")
    when_fragment_expired(@cached_topics_sidebar, @@todays_feeds_sidebar_refresh_time.seconds.from_now) do
      start_date = Time.now.to_date - (params[:timespan] || 1).to_i.days
      joins      = " JOIN taggings ON taggings.tag_id = topics.tag_id AND topics.type IS NULL" + \
                   " JOIN stories ON stories.id=taggings.taggable_id AND taggings.taggable_type='Story'"
      conds      = ["(stories.status = 'queue' OR stories.status = 'pending') AND (stories.sort_date >= ?) AND (stories.autolist_score > ?)", start_date, Feed::TODAYS_FEEDS_MIN_SCORE]
      selects    = "topics.id, topics.name, topics.slug, count(*) as num_stories"
      if @local_site
        joins += " JOIN taggings t2 ON t2.taggable_id = stories.id AND t2.taggable_type='Story' AND t2.tag_id = #{@local_site.constraint_id}"
        conds[0] += " AND topics.local_site_id=#{@local_site.id}"
      else
        conds[0] += " AND topics.local_site_id IS NULL"
      end

      active_topics = Topic.find(:all, :joins => joins, :select => selects, :conditions => conds, :group => "topics.id")
      @top50_topics = active_topics.reject { |x| x.num_stories.to_i < 5} \
                                   .sort { |t1,t2| t2.num_stories.to_i <=> t1.num_stories.to_i }[0..49] \
                                   .sort { |t1,t2| t1.name <=> t2.name }
      joins.sub!("topics.type IS NULL", "topics.type = 'Subject'")
      active_subjects = Topic.find(:all, :joins => joins, :select => selects, :conditions => conds, :group => "topics.id")
      candidate_subj_slugs = (@local_site ? @local_site.landing_page_subject_slugs : LocalSite::NATIONAL_SITE_SUBJECT_SLUGS) 
      candidate_subj_ids = candidate_subj_slugs.collect { |s| Subject.find_subject(s, @local_site) }.compact.map(&:id)
      @top_subjects = active_subjects.reject { |x| !candidate_subj_ids.include?(x.id) }
    end
  end

  def setup_active_feeds_sidebar
    @cached_feeds_sidebar = "#{@local_site ? @local_site.slug + ':' : ''}feeds_sidebar" + (params[:timespan].blank? ? "" : "__ts=#{params[:timespan]}")
    when_fragment_expired(@cached_feeds_sidebar, @@todays_feeds_sidebar_refresh_time.seconds.from_now) do
      c1 = Feed.regular_feeds_finder_condition
      c2 = ["stories.status = 'queue' OR stories.status = 'pending'"]
      c3 = ["stories.sort_date >= ?", Time.now.to_date - (params[:timespan] || 1).to_i.days]
      c4 = ["stories.autolist_score >= ?", Feed::TODAYS_FEEDS_MIN_SCORE]
      active_feeds = Feed.find(:all,
                       :joins => " JOIN story_feeds ON story_feeds.feed_id=feeds.id" + \
                                 " JOIN stories ON stories.id=story_feeds.story_id",
                       :select => "feeds.*, count(*) as num_stories",
                       :conditions => QueryHelpers.conditions_array([c1,c2,c3,c4]),
                       :group => "feeds.id")
      @top100_feeds = active_feeds.reject { |x| x.is_twitter_feed? ? (x.num_stories.to_i < 2) : (x.num_stories.to_i < 10) } \
                                  .sort { |f1,f2| f2.num_stories.to_i <=> f1.num_stories.to_i }[0..99] \
                                  .sort { |f1,f2| f1.name <=> f2.name }
    end
  end
end
