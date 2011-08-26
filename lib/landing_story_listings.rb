# Used by Home, Topics & Subjects Controllers to format the landing-page story listings

module LandingStoryListings

  def load_homepage_listings(local_site, exclude_stories_ids, opts = {})
    no_local           = opts[:no_local] # story listing code automatically handles scenario of local sites
    use_activity_score = opts[:use_activity_score] ? true : false

    max_stories_per_source = LocalSite.max_stories_per_source(local_site)

      # Subject listings -- only news
    story_listing_options = {
      :use_activity_score => use_activity_score,
      :paginate => false,
      :per_page => 2,
      :time_span => LocalSite.default_date_window_size(local_site).days,
      :listing_type => :most_recent,
      :filters => {
        :local_site => local_site,
        :no_local => no_local,
        :story_type => Story::NEWS,
        :sources => { :max_stories_per_source => max_stories_per_source }
      }
    }

    source_counts = {}
    source_exclude_ids = []
    exclude_stories_ids ||= []
    story_listings = (local_site ? local_site.landing_page_subject_slugs : LocalSite::NATIONAL_SITE_SUBJECT_SLUGS).collect { |slug|
      story_listing_options[:filters].merge!({:topic => slug, :exclude_stories => exclude_stories_ids})
      story_listing_options[:filters][:sources][:exclude_ids] = source_exclude_ids
      story_listing_options[:per_page] = Subject.find_subject(slug, local_site).is_minor_subject? ? 1 : 2
      stories = Story.list_stories_with_associations(story_listing_options) || []
        # Process stories to prevent duplicates + restrict each source to at most 2 stories across all subjects
      stories.each { |s|
        exclude_stories_ids << s.id
        src_id = s.primary_source.id
        source_counts[src_id] ||= 0
        source_counts[src_id] += 1
        source_exclude_ids << src_id if source_counts[src_id] == max_stories_per_source
      }
        # Listing for this subject
      { :slug => slug, :stories => stories }
    }

      # Now get all opinion stories
    story_listing_options[:filters].delete(:topic)
    story_listing_options[:filters][:story_type] = Story::OPINION
    story_listings << { :slug => "opinion", :stories =>  Story.list_stories_with_associations(story_listing_options) }

    return story_listings
  end
  
  def load_categorized_story_listings(local_site, listing_type, page_obj=nil, opts = {})
    stories_to_exclude = opts[:stories_to_exclude]
    story_listings = {}
    story_listing_options = {
      :filters => {
        :local_site => local_site,
        # only 1 story per source for high-volume topics & subjects
        :sources  => {:max_stories_per_source => (page_obj && page_obj.class != Group && page_obj.is_high_volume?) ? LocalSite.max_stories_per_source(local_site) : nil},
        :no_local => opts[:no_local]  # Story listing code automatically handles scenario of local sites
      }
    }

    story_listing_options[:listing_type] = listing_type
    if page_obj
      if page_obj.class == Group
        story_listing_options[:filters][:group_id] = page_obj.id
        story_listing_options[:time_span] = page_obj.sg_attrs.listing_date_window_size.days if :most_trusted == listing_type
      else
        story_listing_options[:filters][:topic] = page_obj.slug
      end
    end

    # SSS FIXME: Why a hardcoded timespan for least trusted (as opposed to using the topic volume settings?)
    # Because most often, there aren't enough least trusted stories to pick
    story_listing_options[:time_span] = LocalSite.least_trusted_date_window_size(@local_site).days if listing_type == :least_trusted
    story_listing_options[:filters].merge!(:use_date_window => [:least_trusted,:most_trusted].include?(listing_type))
    if (listing_type == :todays_feeds)
      story_listing_options[:use_activity_score] = true
      story_listing_options[:listing_type_opts] = { :min_score => Feed::TODAYS_FEEDS_MIN_SCORE, :no_pending_scores => true }
      story_listing_options[:filters][:sources][:max_stories_per_source] = LocalSite.max_stories_per_source(local_site)
    end
    ["news", "opinion"].each do |story_type|
      story_listings[story_type] = {}
        # FIXME: This exclude_ids thing is useless now since the same story can't be both a msm and an ind type!
        # If we stick with this setup, we can get rid of this parameter
      story_listing_options[:filters][:sources][:exclude_ids] = [] # empty source dupes for each listing
      ["mainstream", "independent"].each do |source_ownership|
        story_listing_options[:filters][:story_type] = story_type
        case source_ownership
        when "mainstream":
          story_listing_options[:filters][:sources][:ownership] = Source::MSM
          story_listing_options[:per_page] = (page_obj && page_obj.class != Group ? page_obj.num_msm_stories : SocialNewsConfig["landing_pages"]["num_high_volume_msm"])
        when "independent":
          story_listing_options[:filters][:sources][:ownership] = Source::IND
          story_listing_options[:per_page] = (page_obj && page_obj.class != Group ? page_obj.num_ind_stories : SocialNewsConfig["landing_pages"]["num_high_volume_ind"])
        end

          # stories to exclude to prevent it being repeated on a page
        exclude_stories_ids = stories_to_exclude.collect { |s| s.id } if !stories_to_exclude.blank?
        exclude_stories_ids ||= []

          # since we have eliminated one-story-per-source constraint across the page, we may have a story that has fewer than 3 reviews
          # and be listed in both the top-stories and for-review section ... so, find such stories from top-stories and add it to the
          # exclude list when fetching for-review
        if (listing_type == :for_review)
          story_listings[story_type][source_ownership].each { |s| exclude_stories_ids << s.id if s.hide_rating }
        end
        story_listing_options[:filters].merge!(:exclude_stories => exclude_stories_ids)

          # get story listing
        story_listings[story_type][source_ownership] = Story.list_stories_with_associations(story_listing_options)
      end
    end
    return story_listings
  end
  
  # for the 3-dimensional array constructed in load_categorized_story_listings
  def flatten_story_listings(story_listings)
    if story_listings.class == Array
      story_listings.flatten
    else
      story_listings.values.collect{|a| a.values}.flatten
    end
  end

    # Randomize the cache times for each segment by upto +/- 10 seconds
  @@top_area_refresh_time     = SocialNewsConfig["caching"]["refresh_times"]["topic_top_area"]     + (rand(10) - 5)
  @@sidebar_refresh_time      = SocialNewsConfig["caching"]["refresh_times"]["topic_sidebar"]      + (rand(10) - 5)
  @@right_column_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["topic_right_column"] + (rand(10) - 5)
  @@listings_refresh_time     = SocialNewsConfig["caching"]["refresh_times"]["topic_listings"]
  @@listings_refresh_time.keys.each { |k| @@listings_refresh_time[k] += (rand(10) - 5) }

  def load_story_listing(local_site, page_obj, listing_type)
    more_opts = page_obj.class == Group ? {:group_id => page_obj.id} : {:t_slug => page_obj.slug}
    if (listing_type == :starred)
      opts = {:per_page => 10, :listing_type => :starred, :listing_type_opts => {:member_id => current_member ? current_member.id : nil}}
      opts.merge!(more_opts)
      @stories = Story.normalize_opts_and_list_stories_with_associations(local_site, opts)
      []
    elsif (listing_type == :new_stories)
      # Only supported for groups!
      if page_obj.class == Group
        @my_page = true
        @member  = page_obj.sg_attrs.mynews_dummy_member
        params[:listing_type] = nil # SSS: FIXME: What do you know? This param conflicts with mynews!
        config_mynews(@member, @my_page)
      else
        @stories = []
      end
    else
      @cached_fragment_name = get_cached_fragment_name("#{page_obj.slug}:#{listing_type}", nil)
      get_cached_story_ids_and_when_fragment_expired(@cached_fragment_name, @@listings_refresh_time[listing_type.to_s].seconds) do
        @will_be_cached = true
        if listing_type == :todays_feeds
          opts = {:use_activity_score => true, 
                  :paginate => false, 
                  :per_page => 10, 
                  :max_stories_per_source => LocalSite.max_stories_per_source(local_site), 
                  :listing_type_opts => {:min_score => Feed::TODAYS_FEEDS_MIN_SCORE, :no_pending_sources => true}}
          @stories = find_queued_stories(local_site, opts.merge!(more_opts))
        else
          no_local = case page_obj
            when Group   then true
            when Subject then (page_obj.slug != "local")
            when Topic   then !page_obj.subjects.map(&:slug).include?("local")
          end
          @stories = load_categorized_story_listings(local_site, listing_type, page_obj, :no_local => no_local)
        end

          # Last statement in block should yield a flat list of story ids
        flatten_story_listings(@stories).map(&:id)
      end
    end
  end

  def load_grid_settings(local_site, page_obj, listed_story_ids)
    settings = LayoutSetting.load_settings_hash(local_site, page_obj, "grid")

    # What ids are we showing?
    if settings["show_box?"].is_true?
      ids = settings["show_row1?"].is_true? ? [1,2,3] : []
      ids += [4,5,6] if settings["show_row2?"].is_true?
    else
      ids = []
    end

    # Pre-initialize the set of listed story ids for all grid cells where the editors have specified an id
    # This ensures that story listings in other grid cells won't repeat these stories
    ids.each { |i|
      ci = settings["c#{i}"]
      if ci
        ci.unmarshal!
        sid = ci.value["story"] 
        listed_story_ids << sid if !sid.blank?
      end
    }

    # Load up story grid
    stories = ids.collect { |i|
      ci = settings["c#{i}"]
      if ci
        ci_settings = ci.value
        sid = ci_settings["story"]
        if !sid.blank?
          [Story.find(sid), ci_settings["label"]]
        else
          # lt_slug = Listing type slug
          lt_slug = ci_settings["lt_slug"]
          lt_slug = nil if lt_slug.blank?

          # We won't profile stories in the grid that were submitted by members with validation level < 2
          opts = {:min_submitter_level => 2, :paginate => false, :per_page => 1, :exclude_stories => listed_story_ids }
          more_opts = case page_obj
            when nil     then { :no_local => lt_slug.nil? ? false : !Topic.find_topic(lt_slug, @local_site).subjects.map(&:slug).include?("local") }
            when Group   then { :no_local => true, :group_id => page_obj.id, :t_slug => lt_slug }
            when Subject then { :no_local => (page_obj.slug != "local"), :t_slug => lt_slug || page_obj.slug }
            when Topic   then { :no_local => !page_obj.subjects.map(&:slug).include?("local"), :t_slug => lt_slug || page_obj.slug }
          end
          opts.merge!(more_opts)

          # Merge in listing type opts from settings
          # Darn! string/symbol mismatch problems! Use strings, not symbols
          ci_settings["listing"].each { |k,v| opts[k.to_sym] = v }

          # Handle member_picks
          if opts[:listing_type] == "member_picks"
            opts[:listing_type_opts] = { :member_id => Member.find(lt_slug).id }
            opts[:t_slug] = nil
            opts[:min_submitter_level] = nil
          end

          # :fill_story_window => true to force a story be found -- only an issue for most_trusted/ least_trusted stories
          opts.merge!({:paginate => true, :fill_story_window => true}) if ["most_trusted", "least_trusted"].include?(opts[:listing_type])

          # Phew! fetch the story now
          s = Story.normalize_opts_and_list_stories(local_site, opts)[0]
          if s
            listed_story_ids << s.id
            [s, ci_settings["label"]]
          end
        end
      end
    }.compact

    {:settings => settings, :stories => stories, :listed_story_ids => listed_story_ids}
  end

  # Called for topic, subject, and group landing pages
  def load_top_area_stories(local_site, page_obj)
    @top_area_cached_fragment_name = get_cached_fragment_name("#{page_obj.slug}_top_area")
    top_area_story_ids = get_cached_story_ids_and_when_fragment_expired(@top_area_cached_fragment_name, @@top_area_refresh_time.seconds) do
      listed_story_ids = []

      # Staging area
      @featured_story_settings = LayoutSetting.load_settings_hash(local_site, page_obj, "featured_story")
      if @featured_story_settings["show_box?"].is_true?
        fsid = @featured_story_settings["story"]
        if fsid
          fsid = fsid.value.to_i
          @featured_story = Story.find(fsid)
          listed_story_ids << fsid
        end
      end

      gs = load_grid_settings(local_site, page_obj, listed_story_ids)
      @grid_settings = gs[:settings]
      @grid_stories = gs[:stories]

      # Last statement in this block should return provide the list of stories in this cached area
      gs[:listed_story_ids]
    end
  end

  # SSS FIXME: Hacky .. nc_topic is used only for homepage setup (i.e. when page_obj is nil)
  def load_news_comparison_settings(local_site, page_obj, nc_topic, listed_story_ids)
    stories = []
    settings = LayoutSetting.load_settings_hash(local_site, page_obj, "news_comparison")
    if settings["show_box?"].is_true?
      if settings["use_topic_listing?"].is_true?
        settings["topic_listing"].unmarshal!
          # 1. Dont repeat stories
          # 2. Editors don't wany any story with editorial priority below Medium to show up in the grid!
          #    FIXME: 3 is a hard-coded numeric value.  Change all editorial priority refs. to symbolic refs (medium, high, low, etc.)
        opts = { :exclude_stories => listed_story_ids, :paginate => false, :per_page => 3, :edit_priority => 3 }

        more_opts = case page_obj
          when nil     then { :no_local => true, :t_slug => nc_topic.slug }
          when Group   then { :no_local => true, :group_id => page_obj.id }
          when Subject then { :no_local => (page_obj.slug != "local"), :t_slug => page_obj.slug }
          when Topic   then { :no_local => !page_obj.subjects.map(&:slug).include?("local"), :t_slug => page_obj.slug }
        end
        opts.merge!(more_opts)

        # Merge listing-specific settings
        # Darn! string/symbol mismatch problems!
        settings["topic_listing"].value.each { |k,v| opts[k.to_sym] = v }

        # :fill_story_window => true to force a story be found -- only an issue for most_trusted / least_trusted stories
        opts.merge!({:paginate => true, :fill_story_window => true}) if ["most_trusted", "least_trusted"].include?(settings[:listing_type])
        stories = Story.normalize_opts_and_list_stories(local_site, opts)
        more_stories_text = "More stories"
      else
        stories = (1..3).collect { |i| sid = settings["story_#{i}"].value; Story.find(sid) if !sid.blank? }.compact
        more_stories_text = "Compare more stories"
      end

      v = settings["compare_more_stories_link"].value
      more_stories_link = v.blank? ? url_for(page_obj || nc_topic) : v
    else
      stories = []
    end

    {:settings => settings, :stories => stories, :more_stories_text => more_stories_text, :more_stories_link => more_stories_link }
  end

  # Called for topic, subject, and group landing pages
  def load_right_column(local_site, page_obj, listed_story_ids)
    @right_column_cached_fragment_name = get_cached_fragment_name("#{page_obj.slug}_right_column")
    when_fragment_expired(@right_column_cached_fragment_name, @@right_column_refresh_time.seconds.from_now) do
      @right_column_settings = LayoutSetting.load_settings_hash(local_site, page_obj, "right_column")
      case page_obj
        when Subject, Topic 
          opts = {:count_only => true, :listing_type_opts => {:min_score => Feed::TODAYS_FEEDS_MIN_SCORE}}
          opts.merge!((page_obj.class == Group) ? {:group_id => page_obj.id} : {:t_slug => page_obj.slug})
          @num_smart_feed_stories = find_queued_stories(local_site, opts)
          @top_sources = AggregateStatistic.find_statistic(page_obj, "top_sources") # Find the top N sources for this topic/subject
        when Group
          @top_sources = [] # FIXME: Not implemented yet
      end
    end

    @sidebar_cached_fragment_name = get_cached_fragment_name("#{page_obj.slug}_sidebar")
    get_cached_story_ids_and_when_fragment_expired(@sidebar_cached_fragment_name, @@sidebar_refresh_time.seconds) do
      # These settings are used in rendering the right column image
      @right_column_settings   = LayoutSetting.load_settings_hash(local_site, page_obj, "right_column")
      @featured_story_settings = LayoutSetting.load_settings_hash(local_site, page_obj, "featured_story")
      if @featured_story_settings["show_box?"].is_true?
        fsid = @featured_story_settings["story"]
        @featured_story = Story.find(fsid.value.to_i) if fsid
      end

      # Editorial spaces
      @right_column_spaces = EditorialSpace.on_non_homepage(local_site, page_obj.class.name, page_obj.id).find(:all, :conditions => {:context => "right_column"}, :order => "position ASC")

      # News Comparison
      @will_be_cached = true
      ncs = load_news_comparison_settings(local_site, page_obj, nil, listed_story_ids)
      @news_comparison_settings = ncs[:settings]
      @news_comparison_stories = ncs[:stories]
      @news_more_stories_link = ncs[:more_stories_link]
      @news_more_stories_text = ncs[:more_stories_text]
      @news_comparison_stories.map(&:id)
    end
  end
end
