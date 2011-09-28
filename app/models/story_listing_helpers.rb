# NOTE: I am joining the sources table as story_sources alias because in rails 2.3 the eager loading of sources :include option 
# is conflicting with the sources table in the join below.  In rails 2.1, looks like activerecord renamed the eager loaded table
# but not so in 2.3 which is breaking code.
module StoryListingHelpers
  def self.logger; RAILS_DEFAULT_LOGGER; end

# ------------------ Module methods used by story listing code here -------------------

  def self.default_date_window_size(local_site, opts)
    lt = opts[:listing_type] ? opts[:listing_type].to_sym : ""

      # 1. nil for most_recent, for_review, and all_rated_stories
      # 2. for sources, default is max(30 days,topic-specific value), and for others, it is topic-dependent
    if ([:most_recent, :new_stories, :for_review, :recent_reviews, :all_rated_stories, :starred, :member_picks].include? lt)
      nil
    elsif lt == :least_trusted
      LocalSite.least_trusted_date_window_size(local_site)
    elsif (opts[:t_slug] || opts[:s_slug])
      t_slug = opts[:t_slug] || opts[:s_slug]
      # For local sites, double the date window size
      topic = t_slug ? Topic.find_topic(t_slug, local_site) : nil
      topic_days = LocalSite.date_window_size_for_topic_listing(local_site, topic)
      opts[:source].blank? ? topic_days : [30, topic_days].max
    elsif opts[:group]
      opts[:group].sg_attrs.listing_date_window_size
    end
  end

  def self.normalize_options(local_site, opts)
      # Convert all "" values to nil
    opts.keys.each { |k| opts[k] = nil if opts[k].blank? }

      # Convert listing type param to match what the list_stories method expects
    lt = opts[:listing_type]
    lt = lt.to_sym if lt

      # Are we requesting a group listing
    group_id = opts[:group_id] || opts[:g_slug]
    if group_id
      # normalize to a group id if we have a slug instead
      group = Group.find_by_id_or_slug(group_id)
      group_id = group.id
    end

      # Convert source ownership param to match what the list_stories method expects
    case opts[:source_ownership]
      when nil          : ""
      when "mainstream", "msm"  : so_type = Source::MSM
      when "independent", "ind" : so_type = Source::IND
      when "untrusted"  : so_rating_type = Source::UNTRUSTED
      when "trusted"    : so_rating_type = Source::TRUSTED
      when "rated"      : so_rating_type = Source::RATED
      when "unrated"    : so_rating_type = Source::UNRATED
    end

    # This option always overrides the opts[:source_ownership] value -- that is really meant for source ownership which
    # we have overloaded with rating class!
    so_rating_type = opts[:source_rating_class] if !opts[:source_rating_class].blank?

      # Set up num_days
    timespan = opts[:timespan]
    begin
      case timespan
        when "", nil : dw = default_date_window_size(local_site, opts.merge(:group => group)); num_days = dw ? dw.days : nil
        when "day"   : num_days = 1.day
        when "week"  : num_days = 1.week
        when "month" : num_days = 1.month
        when "year"  : num_days = 1.year
        when "all"   : num_days = nil
          # Interpret the parameter as an integer number of days!
        else           num_days = timespan.to_i.days
      end
    rescue Exception => e
      logger.error "Exception: #{e} while parsing timespan param #{timespan}"
    end

      # For most trusted & least trusted, always look within a date window, 
      # rather than stare into eternity (unless we have been asked to!)
    use_date_window = (timespan != "all") && [:most_trusted, :least_trusted].include?(lt)

      # Story status opts
    status = [ opts[:story_status] ].flatten if !opts[:story_status].blank?

      # Construct the options hash
    ret = {
      :listing_type => lt,
      :time_span    => (opts[:review_start_date].nil? && opts[:review_end_date].nil?) ? num_days : nil,
      :start_date   => opts[:start_date] ? Time.parse(opts[:start_date]) : nil,
      :end_date     => opts[:end_date]   ? Time.parse(opts[:end_date])   : nil,
      :filters      => { :local_site => local_site, # Set in application controller based on subdomain of incoming request!
                         :topic    => (opts[:t_slug] || opts[:s_slug]),
                         :status   => status,
                         :feed     => opts[:feed_id],
                         :group_id => group_id,
                         :use_date_window => use_date_window,
                         :min_editorial_priority => opts[:edit_priority],
                         :sources  => {
                           :slug         => opts[:source],
                           :ownership    => so_type,
                           :rating_class => so_rating_type,
                         },
                         :review => {
                           :start_date => opts[:review_start_date] ? Time.parse(opts[:review_start_date]) : nil,
                           :end_date   => opts[:review_end_date]   ? Time.parse(opts[:review_end_date])   : nil,
                           :timespan   => (opts[:review_start_date].nil? && opts[:review_end_date].nil?) ? nil : num_days,
                           :sort_by    => opts[:sort_by]
                         }
                       }
    }

      # Pass thru' incoming opts
    [:listing_type_opts, :use_activity_score, :count_only, :all, :include, :paginate, :page, :per_page, :more_conditions, :fill_story_window].each { |k| ret[k] = opts[k] }
    [:no_local, :exclude_stories, :story_type, :content_type, :min_reviews, :min_submitter_level].each { |k| ret[:filters][k] = opts[k] }
    [:media_type, :max_stories_per_source].each { |k| ret[:filters][:sources][k] = opts[k] }
    ret
  end

# ------------ Sanitize listing options -------------
  def self.sanitize_listing_options(options)
    options[:listing_type] = :most_recent    if options[:listing_type].blank? 
    options[:listing_type] = :queued_stories if options[:listing_type] == :todays_feeds # :todays_feeds & :queued_stories are synonyms
    options[:listing_type] = :starred        if options[:listing_type] == :member_picks # :starred & :member_picks are synonyms

    filters = (options[:filters] || {})

    # Convert listing options to the form they are expected
    if filters[:source_ids]
      filters[:sources] ||= {}
      filters[:sources][:ids] = filters[:source_ids]
      filters.delete(:source_ids)
    end

    source_filters = filters[:sources]
    if [:all_rated_stories, :most_recent, :most_trusted, :least_trusted].include?(options[:listing_type])
      if !filters[:min_story_rating].nil?
        logger.error "Incompatible story listing options: Cannot use the min_story_rating filter with #{options[:listing_type]} listings."
        raise "Incompatible story listing options: Cannot use the min_story_rating filter with #{options[:listing_type]} listings."
      end
      if source_filters && !source_filters[:min_rating].nil?
        logger.error "Incompatible story listing options: Cannot use the source min rating filter with #{options[:listing_type]} listings."
        raise "Incompatible story listing options: Cannot use the source min rating filter with #{options[:listing_type]} listings." 
      end
    end

    if source_filters && source_filters[:max_stories_per_source] && (options[:paginate] || options[:all] || options[:count_only])
      logger.error "Incompatible story listing options: 'atmost-one-story-per-source' and 'paginate' / 'all / 'count_only' are mutually exclusive!  They cannot be used at the same time!"
      raise "Incompatible story listing options: 'atmost-one-story-per-source' and 'paginate' / 'all / 'count_only' are mutually exclusive!  They cannot be used at the same time!"
    end

    if source_filters && source_filters[:min_rating] && [Source::TRUSTED, Source::UNTRUSTED].include?(source_filters[:rating_class])
      logger.error "Incompatible story listing options: Cannot use source min rating filter along with #{source_filters[:rating_class]} source rating class filter"
      raise "Incompatible story listing options: Cannot use source min rating filter along with #{source_filters[:rating_class]} source rating class filter"
    end

    if options[:fill_story_window] && options[:count_only]
      logger.error "Incompatible story listing options: 'fill-story-window' and 'count_only' are mutually exclusive!  They cannot be used at the same time!"
      raise "Incompatible story listing options: 'fill-story-window' and 'count_only' are mutually exclusive!  They cannot be used at the same time!"
    end

    if options[:all] && (options[:paginate] || options[:fill_story_window])
      logger.error "Incompatible story listing options: 'all' and 'paginate' / 'fill_story_window' are mutually exclusive!  They cannot be used at the same time!"
      raise "Incompatible story listing options: 'all' and 'paginate' / 'fill_story_window' are mutually exclusive!  They cannot be used at the same time!"
    end

    # Pass through some top-level options via the filters hash
    filters[:lt] = options[:listing_type]
    filters[:dw] = { :start_date => options[:start_date], :end_date => options[:end_date], :time_span => options[:time_span] }

    # For all listings, when 'max_stories_per_source' is in effect, window by some timespan
    # so that the query doesn't degenerate into a full-table scan!
    max_stories_per_source = source_filters && source_filters[:max_stories_per_source]
    filters[:use_date_window] = filters[:use_date_window] || max_stories_per_source 

    # Replace topic slug with the topic itself!
    filters[:topic] = filters[:topic] ? Topic.find_topic(filters[:topic], filters[:local_site]) : nil

    # Set up start & end dates
    dw_opts = filters[:dw]
    ed = dw_opts[:end_date]
    sd = dw_opts[:start_date]
    now = Time.now
    if !sd
      topic = filters[:topic]
      ts = dw_opts[:time_span]
      if !ts
        ts = filters[:use_date_window] ? LocalSite.date_window_size_for_topic_listing(filters[:local_site], topic).days : nil
      end
      sd = (ed || now) - ts if (ts)
    end
    if !ed && dw_opts[:time_span]
      ed = (sd || now) + dw_opts[:time_span]
      ed = nil if (ed > now)
    end
    dw_opts[:start_date] = sd
    dw_opts[:end_date] = ed

    # Ignore min_submitter_level filter if we are fetching recently reviewed stories
    filters[:min_submitter_level] = nil if [:recent_reviews, :trusted_reviews].include?(options[:listing_type])

    # Ignore no-local filter if we are on a local site!
    # Set it if it is not set
    if !filters[:local_site].nil?
      filters[:no_local] = nil
    elsif filters[:no_local].nil?
      t = filters[:topic]
      if t
        filters[:no_local] = true if ((t.class == Subject) && (t.slug != "local")) || ((t.class == Topic) && !t.subjects.map(&:slug).include?("local"))
      elsif filters[:topic_ids]
        no_local = true
        # if any of the topics or subjects is local, then we want local stories and will turn off no_local filter
        ts = Topic.find(:all, :conditions => {:id => filters[:topics_ids], :local_site_id => filters[:local_site] ? filters[:local_site].id : nil})
        ts.each { |t|
          if ((t.class == Subject) && (t.slug == "local")) || ((t.class == Topic) && t.subjects.map(&:slug).include?("local"))
            no_local = false
            break
          end
        }
        filters[:no_local] = true if no_local
      elsif filters[:group_id].nil?
        filters[:no_local] = true
      end
    end

    # Reset the filters hash in options
    options[:filters] = filters
  end

# ------------ set up listing filters -------------
# 1. Go through the list of classes defined in this module and invoke the filter method on those classes
# 2. Accumulate the list of condition, join clauses, and anything else

  def self.setup_all_filters(opts)
    self.constants.inject({ :group_by => [], :distinct => false, :conditions => [], :joins => [], :left_joins => [], :index_hint => nil}) { |h, c|
        # Invoke the filter and merge in its results
      f = const_get(c)

      # Used to be: (f.send(:filter, opts) || {}).each { |k,v| h[k] = (h[k] || []) + v if v } if f.class == Module
      # I've broken it up into multiple lines so it is easier to figure out what is going on

        # Ignore non-module contants -- they are not filters
      if (f.class == Module)
        filter_output = f.send(:filter, opts) || {}
        filter_output.each { |k,v| h[k] = (h[k] || []) + v if v }
      end
      h
    }
  end

  def self.get_source_rating_check_clause(local_site, source_rating_class)
    # NOTE: modify source.rb/hide_rating whenever you modify clauses here
    tbl = local_site.nil? ? "story_sources" : "source_stats"
    case source_rating_class
      when nil               then ""
      when Source::LISTED    then "(story_sources.status IN ('#{Source::LIST}', '#{Source::FEATURE}'))"
      when Source::UNTRUSTED then "(#{tbl}.rating < #{SocialNewsConfig['min_trusted_source_rating']})"
      when Source::TRUSTED   then "(#{tbl}.rating >= #{SocialNewsConfig['min_trusted_source_rating']})"
      when Source::UNRATED   then "(#{tbl}.reviewed_stories_count < #{SocialNewsConfig['min_stories_for_source_rating']} OR #{tbl}.story_reviews_count < #{SocialNewsConfig["min_reviews_for_source_rating"]})"
      when Source::RATED     then "(#{tbl}.reviewed_stories_count >= #{SocialNewsConfig['min_stories_for_source_rating']} AND #{tbl}.story_reviews_count >= #{SocialNewsConfig["min_reviews_for_source_rating"]})"
    end
  end

# ------------ set up listing types -------------
  # handle listing types, predefined & custom
  def self.setup_listing_type(options, requested_srcs)
    conds    = []
    joins    = []
    order_by = ""
    distinct = false
    index_hint = nil
    filters    = options[:filters]
    local_site = filters[:local_site]
    for_group  = !filters[:group_id].blank?
    sort_table = for_group ? "group_stories" : "stories"

    case options[:listing_type]
      when :mynews_active, :mynews_inactive
        conds << ["stories.rating IS NOT NULL AND stories.sort_date IS NOT NULL", nil]
        conds << ["stories.status != 'hide'", nil] if filters[:ignore_story_status] # default status for mynews
        conds << ["stories.activity_score >= ?", options[:listing_type_opts][:min_activity_score]] if options[:listing_type_opts][:min_activity_score]
        conds << ["stories.activity_score < ?", options[:listing_type_opts][:max_activity_score]] if options[:listing_type_opts][:max_activity_score]
        if requested_srcs.blank? && (filters[:mynews].blank? || filters[:mynews][:source_ids].blank?)
          joins += ["members ON members.id=stories.submitted_by_id"]
          conds << ["(story_sources.status IN (?) OR members.validation_level >= ?)", [Source::LIST, Source::FEATURE], SocialNewsConfig["min_trusted_member_validation_level"].to_i] 
        end
        order_by = options[:listing_type_opts][:order_by] || "stories.activity_score DESC, stories.sort_date DESC, #{sort_table}.sort_rating DESC"

      when :most_trusted
        [Story::RATED, Story::TRUSTED].each { |rc| conds << [ Story.get_rating_check_clause(rc, for_group), nil ] }
        order_by = "#{sort_table}.sort_rating DESC, stories.sort_date DESC, stories.id DESC"

      when :least_trusted
        [Story::RATED, Story::UNTRUSTED].each { |rc| conds << [ Story.get_rating_check_clause(rc, for_group), nil ] }
        order_by = "#{sort_table}.sort_rating ASC, stories.sort_date DESC, stories.id DESC"

      when :most_recent
        if !requested_srcs.blank?
          # No constraints whatsoever when we are picking stories for a specific source (or set of sources)
          order_by = "stories.sort_date DESC, #{sort_table}.sort_rating DESC, stories.id DESC"
        else
          # 1. Filter for rated stories -- reject rated, but untrusted stories
          #
          # So, one of the following must hold:
          #   (a) the story is unrated
          #   (b) the story is trusted
          #
          # (excludes rated but untrusted stories)
          conds << ["(#{Story.get_rating_check_clause(Story::UNRATED, for_group)} OR #{Story.get_rating_check_clause(Story::TRUSTED, for_group)})", nil]

          # 2. Filter for unrated stories -- reject unrated stories from bad sources, unless editors have picked this story 
          #
          # So, one of the following must hold:
          #   (a) the story should be rated
          #   (b) the story should have "high" editorial priority value
          #   (c) the story should be from a rated & trusted source
          #   (d) the story should be from a source with a high editorial priority (>= 4)
          high_src_edit_priority = SocialNewsConfig["min_editorial_priority_for_most_recent"]
          story_checks  = "#{Story.get_rating_check_clause(Story::RATED, for_group)} OR (stories.editorial_priority >= #{high_src_edit_priority})"
          joins        += ["source_stats ON source_stats.source_id=story_sources.id AND source_stats.local_site_id=#{local_site.id}"] if local_site
          source_checks = "#{get_source_rating_check_clause(local_site, Source::RATED)} AND #{get_source_rating_check_clause(local_site, Source::TRUSTED)}"
          conds << ["(#{story_checks} OR (#{source_checks}) OR story_sources.editorial_priority >= #{SocialNewsConfig["min_source_editorial_priority_for_most_recent"]})", nil]

          # Sort order
          order_by = "stories.sort_date DESC, #{sort_table}.sort_rating DESC, stories.id DESC"

          # Index hints, required if we are
          #   -- fetching a high-volume listing on any page
          #   -- on a high-volume topic/subject page
          source_filters = filters[:sources]
          t_or_s = filters[:topic]
          high_volume_page_listing = !source_filters.nil? && !source_filters[:max_stories_per_source].nil?
          if high_volume_page_listing || (!t_or_s.nil? && t_or_s.is_high_volume?)
            stype_filter = filters[:story_type]
            index_hint = stype_filter.blank? ? "index_stories_on_sort_date_and_sort_rating" : "index_stories_on_stype_code_and_sort_date_and_sort_rating" 
          end
        end

      when :queued_stories
        options[:listing_type_opts] ||= { :min_score => 1.0 } # by default, only stories with min score 1 are returned
        unless options[:listing_type_opts][:min_score].blank?
          conds << ["stories.autolist_score >= ?", options[:listing_type_opts][:min_score]]
        end
        if options[:listing_type_opts] && options[:listing_type_opts][:no_pending_sources]
          if !requested_srcs.blank?
            joins += ["sources AS story_sources ON story_sources.id=stories.primary_source_id AND story_sources.status != 'pending'"]
          else
            conds << ["story_sources.status != 'pending'", nil]
          end
        end

        if options[:use_activity_score]
          order_by = "stories.activity_score DESC, stories.sort_date DESC"
        else
          order_by = "stories.sort_date DESC, stories.autolist_score DESC"
        end

      when :starred:
        joins += ["saves ON stories.id=saves.story_id"]
        if filters[:group_id]
          joins += ["memberships ON memberships.membershipable_type = 'Group' AND memberships.membershipable_id=#{filters[:group_id]} AND memberships.member_id=saves.member_id"]
          distinct = true
        else
          conds << ["saves.member_id = ?", options[:listing_type_opts][:member_id]]
        end
        order_by = "stories.sort_date DESC"

      when :for_review:
        max_stories_per_source = filters[:sources] && filters[:sources][:max_stories_per_source]
        conds << [Story.get_rating_check_clause(Story::UNRATED, for_group), nil]
        conds << ["(stories.editorial_priority >= ?)", SocialNewsConfig["min_editorial_priority_for_review"]] if max_stories_per_source
        # After sort_date, we want to order by editorial priority next, and source rating last.
        # The sort_rating field is perfect for this (Check story.rb sort rating calculation comments to understand this)
        order_by = "stories.sort_date DESC, #{sort_table}.sort_rating DESC"

      when :recent_reviews:
        joins += ["reviews ON stories.id=reviews.story_id"]
        joins += ["members ON members.id=reviews.member_id AND members.validation_level >= 2"]
        conds << ["reviews.comment != ''", nil] if options[:listing_type_opts] && options[:listing_type_opts][:with_notes_only]
        if filters[:review] && (filters[:review][:start_date] || filters[:review][:end_date])
          case filters[:review][:sort_by]
            when "most_trusted"
              order_by = "stories.rating DESC, reviews.created_at DESC"  # do not use sort-rating, because the ordering can be baffling
            when "least_trusted"
              order_by = "stories.rating ASC, reviews.created_at DESC"   # do not use sort-rating, because the ordering can be baffling
            else
              # If we have a fixed date window for fetching reviews, order the reviewed stories 
              # by review rating and then the story rating.
              order_by = "stories.sort_rating DESC, reviews.created_at DESC"
          end
        else
          # SSS: Only look for reviews within a 28 day window -- does anyone care for reviews older than that?
          conds << ["reviews.created_at > ? ", Time.now - 28.days]
          order_by = "reviews.created_at DESC"
        end

      when :trusted_reviews:
        [Story::RATED, Story::TRUSTED].each { |rc| conds << [ Story.get_rating_check_clause(rc), nil ] }
        joins += ["reviews ON stories.id=reviews.story_id"]
        joins += ["members ON members.id=reviews.member_id AND members.validation_level >= 2 AND members.rating >= #{SocialNewsConfig["min_trusted_member_level"]}"]
        order_by = "reviews.created_at DESC"

      when :all_rated_stories:
        conds << [Story.get_rating_check_clause(Story::RATED, for_group), nil]
        order_by = "stories.sort_date DESC, #{sort_table}.sort_rating DESC, stories.id DESC"

      when :activity_listing:
        joins += ["members ON members.id=stories.submitted_by_id"]
        order_by = "activity_score DESC, sort_date DESC, sort_rating DESC"
        conds << ["(story_sources.status IN (?) OR members.validation_level >= ?)", [Source::LIST, Source::FEATURE], SocialNewsConfig["min_trusted_member_validation_level"].to_i] 

      when :new_stories:
        order_by = "stories.sort_date DESC, stories.sort_rating DESC"

      when :custom:
        order_by = options[:sort_orders].collect { |o| "stories.#{o}" } * ", "
    end

    { :conditions => conds, :joins => joins, :left_joins => [], :order_by => order_by, :distinct => distinct, :index_hint => index_hint }
  end

# ------------------ Various story listing filters down below -------------------
#
# If you want to implement a new story listing filter, 
# - define a class for that filter
# - in that class, define a class method "def filter(opts)" here opts is an hash of filter options
# - return a hash with information you want to pass back.  IMPORTANT: Every value in this hash should be an array

  private

  # Filter to check for story status (hide, list, feature)
  module StoryStatusFilter
      ## Default status filters by listing type 
    STATUS_FILTERS     = { :queued_stories => [Story::QUEUE, Story::PENDING] }
    NEG_STATUS_FILTERS = { :new_stories => [Story::HIDE], :activity_listing => [Story::HIDE], :mynews_active => [Story::HIDE], :mynews_inactive => [Story::HIDE] }

    def self.filter(opts)
      if !opts[:ignore_story_status]
        op, status = "=",  opts[:status]
        op, status = "=",  STATUS_FILTERS[opts[:lt]] if status.blank?
        op, status = "!=", NEG_STATUS_FILTERS[opts[:lt]] if status.blank?
        op, status = "=",  [ Story::LIST, Story::FEATURE ] if status.blank?
        { :conditions => [["(" + status.map { |s| "(stories.status #{op} '#{s}')" } * " OR " + ")", nil]] }
      end
    end
  end

  # Filter to pick only specific content types
  module ContentTypeFilter
    def self.filter(opts)
      ctype = opts[:content_type]
      return nil if ctype.blank?

      ctype += "_streaming" if ["audio", "video"].include?(ctype)
      { :conditions => [["stories.content_type = ?", ctype]] }
    end
  end

  # Filter to check for editorial_priority (min_editorial_priority)
  module EditorialPriorityFilter
    def self.filter(opts)
      { :conditions => [["stories.editorial_priority >= ?", opts[:min_editorial_priority]]] } if opts[:min_editorial_priority]
    end
  end

  # Filter to check for member level of story submitter
  module SubmittingMemberLevelFilter
    def self.filter(opts)
      { :joins => ["members ON members.id = stories.submitted_by_id AND members.validation_level >= #{opts[:min_submitter_level]}"] } if !opts[:min_submitter_level].blank?
    end
  end

  # Filter to enforce minimum # of reviews
  module MinReviewsFilter
    def self.filter(opts)
      table_name = opts[:group_id].blank? ? "stories" : "group_stories"
      { :conditions => [["#{table_name}.reviews_count >= ?", opts[:min_reviews]]] } if opts[:min_reviews]
    end
  end

  # Filter to enforce minimum story rating
  module MinStoryRatingFilter
    def self.filter(opts)
      table_name = opts[:group_id].blank? ? "stories" : "group_stories"
      { :conditions => [["#{table_name}.rating >= ?", opts[:min_story_rating]]] } if opts[:min_story_rating]
    end
  end

  # Filter to exclude stories
  module StoryExcludeFilter
    def self.filter(opts)
      { :conditions => [["stories.id NOT IN (#{opts[:exclude_stories] * ','})", nil]] } if !opts[:exclude_stories].blank?
    end
  end

  # Filter to fetch stories for a specific feed
  module FeedFilter
    def self.filter(opts)
      if !opts[:feed_ids].blank?
        { :joins => ["story_feeds ON story_feeds.story_id = stories.id"], :conditions => [["story_feeds.feed_id IN (?)", opts[:feed_ids]]], :group_by => ["stories.id"] }
      elsif !opts[:feed].blank?
        { :joins => ["story_feeds ON story_feeds.story_id = stories.id"], :conditions => [["story_feeds.feed_id = ?", opts[:feed]]] }
      end
    end
  end

  # Filter to fetch posts / reviews from a specific member
  module MemberPostsAndReviewsFilter
    def self.filter(opts)
      # We need a left join on the reviews table so that we still pick story rows that don't have a corresponding review by the desired members
      # With an inner join, we'll prune all rows that dont have a review by the desired members.
      if !opts[:member_ids].blank?
        left_joins = ["reviews ON reviews.story_id=stories.id"]
        conds = [["(stories.submitted_by_id IN (?) OR reviews.member_id IN (?))", opts[:member_ids], opts[:member_ids]]]
        { :left_joins => left_joins, :conditions => conds, :group_by => ["stories.id"] }
      elsif !opts[:member].blank?
        left_joins = ["reviews ON reviews.story_id=stories.id"]
        conds = [["(stories.submitted_by_id = ? OR reviews.member_id = ?)", opts[:member_ids], opts[:member_ids]]]
        { :left_joins => left_joins, :conditions => conds, :group_by => ["stories.id"] }
      end
    end
  end

  # Filter stories by topic/subject
  module TopicFilter
    def self.filter(opts)
      return nil if opts[:topic].blank? && opts[:topic_ids].blank?

      joins = ["taggings ON stories.id=taggings.taggable_id"]
      conds = [["taggings.taggable_type = ?", Story.name]]
      if !opts[:topic_ids].blank?
        joins << "topics ON topics.tag_id = taggings.tag_id"
        conds << ["topics.id IN (?)", opts[:topic_ids]]
        { :conditions => conds, :joins => joins, :group_by => ["stories.id"] }
      else
        # 1. Fetch the tag, rather than the topic since that is what we need
        # 2. Fetch the topic tag separately (rather than use a join) -- this will most likely from a cache! (when object caching is implemented)
        conds << ["taggings.tag_id = ?", opts[:topic].tag_id]
        { :conditions => conds, :joins => joins }
      end
    end
  end

  # story rating class filter
  module StoryRatingClassFilter
    def self.filter(opts)
      conds = []
      opts[:story_rating_classes].each { |c| conds << [ Story.get_rating_check_clause(c, !opts[:group_id].blank?), nil ] } if opts[:story_rating_classes]
      { :conditions => conds }
    end
  end

  module SourcesFilter
    def self.filter(opts)
      source_filters = opts[:sources]
      requested_srcs = nil
      joins = []
      conds = []
      if source_filters
        if (source_filters[:id] || source_filters[:slug])
            # Fetch the source separately (rather than use a join) -- this will most likely come from a cache! (when object caching is implemented)
          requested_srcs = [source_filters[:id] ? Source.find(source_filters[:id]) : Source.find_by_slug(source_filters[:slug])]
            # Don't use primary_source id, join authorships to consider stories with multiple source authorships  
          joins << "authorships ON authorships.source_id = #{requested_srcs[0].id} AND authorships.story_id = stories.id"
        elsif source_filters[:ids]
          requested_srcs = Source.find(:all, :conditions => ["id in (?)", source_filters[:ids]])
          joins << "authorships ON authorships.story_id = stories.id"
          conds << ["authorships.source_id in (?)", source_filters[:ids]]
        elsif source_filters[:media_type]
          conds << ["stories.primary_source_medium = ?", source_filters[:media_type]]
        elsif !source_filters[:exclude_ids].blank?
          conds << ["stories.primary_source_id NOT IN #{Story.array_to_sql(source_filters[:exclude_ids], false)}", nil]
        end
      end

      # If we have been asked to list stories by source, no point considering the source status or rating!
      if requested_srcs.blank? && (opts[:mynews].blank? || opts[:mynews][:source_ids].blank?)
        # This works okay even with :max_stories_per_source requirement, because we are joining on the same field used to meet that req.
        join_clause = "sources AS story_sources ON (story_sources.id = stories.primary_source_id) AND (story_sources.status != 'hide')"
        if source_filters
          if source_filters[:rating_class]
            local_site = opts[:local_site]
            join_clause += " AND #{StoryListingHelpers.get_source_rating_check_clause(local_site, source_filters[:rating_class])}"
            if local_site
              joins << "source_stats ON source_stats.source_id=story_sources.id AND source_stats.local_site_id=#{local_site.id}" 
            end
          end
          join_clause += " AND story_sources.rating >= #{source_filters[:min_rating]}" if source_filters[:min_rating]
        end
        joins << join_clause

        # FIXME: If I do the include below, looks like Rails first does a 'distinct' stories limited-load query, and then does
        # the new consolidated query to fetch stories with sources.  But, the 'distinct' limited-load query requires a file sort
        # for some of these queries (as per the explain command in mysql) -- and can be expensive!
        #
        # For now, commenting this off ... revisit this later
        #
        #  # I can as well include sources since they are being joined above
        # includes = ["sources"]
      end

      { :conditions => conds, :joins => joins, :requested_srcs => requested_srcs }
    end
  end

  # story type filters -- msm-news, ind-opinion, etc.
  module StoryTypeFilter
    def self.filter(opts)
      conds = []
      stype_filter   = opts[:story_type]
      source_filters = opts[:sources]
      source_ownership_filter = source_filters ? source_filters[:ownership] : nil
      if source_ownership_filter && (source_ownership_filter == Source::MSM)
        if (stype_filter && stype_filter == Story::NEWS)
          conds << ["stories.stype_code = #{Story::MSM_NEWS}", nil]
        elsif (stype_filter && stype_filter == Story::OPINION)
          conds << ["stories.stype_code = #{Story::MSM_OPINION}", nil]
        else
          conds << ["(stories.stype_code = #{Story::MSM_NEWS} OR stories.stype_code = #{Story::MSM_OPINION})", nil]
        end
      elsif source_ownership_filter && (source_ownership_filter == Source::IND)
        if (stype_filter && stype_filter == Story::NEWS)
          conds << ["stories.stype_code = #{Story::IND_NEWS}", nil]
        elsif (stype_filter && stype_filter == Story::OPINION)
          conds << ["stories.stype_code = #{Story::IND_OPINION}", nil]
        else
          conds << ["(stories.stype_code = #{Story::IND_NEWS} OR stories.stype_code = #{Story::IND_OPINION})", nil]
        end
      elsif stype_filter && (stype_filter == Story::NEWS)
        conds << ["(stories.stype_code = #{Story::MSM_NEWS} OR stories.stype_code = #{Story::IND_NEWS})", nil]
      elsif stype_filter && (stype_filter == Story::OPINION)
        conds << ["(stories.stype_code = #{Story::MSM_OPINION} OR stories.stype_code = #{Story::IND_OPINION})", nil]
      end

      { :conditions => conds }
    end
  end

  module DateFilter
    def self.filter(opts)
      # Set up start/end date conditions, if applicable
      ed = opts[:dw][:end_date]
      sd = opts[:dw][:start_date]

      conds = []
      conds << ["stories.sort_date <= ?", ed.to_date] if ed
      conds << ["stories.sort_date >= ?", sd.to_date] if sd

      { :conditions => conds }
    end
  end

  module ReviewDateFilter
    # SSS FIXME: Assumes that the reviews table has been joined already
    # So, this only works for recent_reviews listings.
    def self.filter(opts)
      if opts[:review]
        sd = opts[:review][:start_date]
        ed = opts[:review][:end_date]
        ts = opts[:review][:timespan]
        now = Time.now
        if ts || ed || sd
          sd ||= (ed || now) - ts if ts
          ed ||= (sd || now) + ts if ts
          ed = nil if ed && ed > now

          # Round off end timestamp to end of day to make reviews inclusive of entire day
          conds = []
          conds << ["reviews.created_at <= ?", ed.end_of_day] if ed
          conds << ["reviews.created_at >= ?", sd.beginning_of_day] if sd
          { :conditions => conds }
        end
      end
    end
  end

  module NoLocalFilter
    def self.filter(opts)
      # We ignore local site filter on group pages
      if opts[:no_local] && opts[:group_id].blank?
        # SSS: Try number 3 -- no longer using the 'local' subject tag
        { :conditions => [["stories.is_local IS NULL OR stories.is_local = ?", false]] }
      end
    end
  end

  module HideReadStoriesFilter
    def self.filter(opts)
      if opts[:hide_read]
#        { :conditions => [["NOT EXISTS (SELECT story_clicks.id FROM story_clicks WHERE story_clicks.story_id = stories.id AND story_clicks.data = '?')", opts[:hide_read]]] }
        { :left_joins => ["story_clicks ON story_clicks.story_id = stories.id AND story_clicks.data = '#{opts[:hide_read]}'"],
          :conditions => [["story_clicks.id IS NULL", nil]] }
      end
    end
  end

  module GroupFilter
    def self.filter(opts)
      if opts[:group_id]
        { :joins => ["group_stories ON group_stories.story_id = stories.id"], :conditions => [["group_stories.group_id = ?", opts[:group_id]]] } 
      end
    end
  end

  module LocalSiteFilter
    def self.filter(opts)
      if opts[:local_site]
        { :joins      => ["taggings t2 ON stories.id=t2.taggable_id"],
          :conditions => [["t2.taggable_type = ?", Story.name], ["t2.tag_id = ?", opts[:local_site].constraint.id]] }
      end
    end
  end
end
