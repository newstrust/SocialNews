module MynewsListing
  MYNEWS_DEFAULT_SETTINGS = {
    :stories_per_page       => ["int", 10],
    :story_status           => ["string", nil],
#    :story_type             => ["string", nil],     # No constraint - both news & opinion
    :source_ownership       => ["string", nil],     # No constraint - both msm & ind
    :source_status          => ["string", nil],
#    :max_stories_per_source => ["int", nil],     # No constraint
    :media_type             => ["string", nil],     # No constraint 
    :max_story_age          => ["int", 3],          # Stories no older than 3 days
    :min_matching_criteria  => ["int", 1],          # Sufficient if a story matches 1 criteria 
    :public_mynews          => ["string", "members"],
    :show_details           => ["bool", false],     # detailed story info is hidden by default!
    :hide_reviewed_stories  => ["bool", true],      # Do not show stories I've reviewed!
    :hide_read_stories      => ["bool", false],     # Do not show stories I've read
#    :mynews_homepage        => ["int", false],
  }

  private 

  MIN_ACTIVITY_SCORE = 11

  # Larger values makes relevance more important; Smaller values makes timeliness more important (useful to have it between 0.25 and 1)
  TIMELINESS_KNOB    = 0.4

    # Larger the absolute numbers, more likely that older stories with more matches will show up.
    # So, tweak these values up or down depending on how important it is to get more recent stories.
  MATCH_BOOSTS = {
    :member  => TIMELINESS_KNOB * 2.50,
    :source  => TIMELINESS_KNOB * 2.00,
    :feed    => TIMELINESS_KNOB * 2.00,
    :topic   => TIMELINESS_KNOB * 1.50,
    :subject => TIMELINESS_KNOB * 0.25,
  }

  MATCH_DECAY_FACTORS = {
    :member  => 0.67, # match influence capped at 3x
    :source  => 0.10, # match influence capped at 1.1x  -- because it is weird to have multiple matching sources for a story!
    :feed    => 0.80, # match influence capped at 5x
    :topic   => 0.60, # match influence capped at 2.5x  -- because topic tags is not reliable across stories
    :subject => 0.20, # match influence capped at 1.25x -- because subject tags are overarching!
  }

  MYNEWS_ORDERINGS = {
    :mynews_active => {
      :most_recent   => "stories.sort_date DESC, stories.activity_score DESC, stories.sort_rating DESC",
      :most_trusted  => "stories.sort_rating DESC, stories.sort_date DESC, stories.activity_score DESC",
      :most_relevant => "stories.activity_score DESC, stories.sort_date DESC, stories.sort_rating DESC"
    },
    :mynews_inactive => {
      :most_relevant => "stories.sort_date DESC, stories.sort_rating DESC"
    },
  }

  def mynews_settings(member, my_page=true)
    # Set up base listing options
    settings = {}
    MYNEWS_DEFAULT_SETTINGS.each { |k,def_val|
      k = k.to_sym
      val = member.send(k)
      if val.blank?
        settings[k] = def_val[1]
      else
        settings[k] = case def_val[0]
          when "string" then val
          when "int"    then val.to_i
          when "bool"   then (val == "true" || val == "1") ? true : false
          else raise "Unknown Default Setting Type!"
        end
      end
    }

    # If I am seeing another member's mynews page, use default values (rather than the member's values) for some settings
    [:stories_per_page, :show_details].each { |s| settings[s] = MYNEWS_DEFAULT_SETTINGS[s][1] } if !my_page

    return settings
  end

  def followed_items_hash(member)
    { :empty   => member.followed_items.blank?,
      :feeds   => member.followed_feeds.sort   { |a,b| a.name <=> b.name },
      :sources => member.followed_sources.sort { |a,b| a.name <=> b.name },
      :members => member.followed_members.sort { |a,b| a.name <=> b.name },
      :topics  => member.followed_topics.sort  { |a,b| a.name <=> b.name } }
  end

  def mynews_stories(params, member, followed_items, settings)
    if followed_items[:empty]
       { :stories => [] }
    else
      mynews_ordering = params[:listing_type] || :most_relevant
      num_reqd    = settings[:stories_per_page]
      num_stories = num_reqd

      if mynews_ordering == :most_relevant
        # Fetch 5x the number so that we have a bigger window of stories to list relevant stories 
        # NOTE: Strictly speaking, I need to fetch ALL stories and then find # matching criteria on all of them,
        # but that is going to be really expensive, plus we are really more interested in newer stories even if
        # fewer criteria match when compared to older stories ... so, fudge!
        num_stories *= 5 

        # Fetch more stories if we are hiding reviewed stories!
        # Assuming an avg. of 5 reviews a day
        # But if we are hiding read stories, dont bother -- since reviewed stories will get hidden automatically.
        num_stories += 5 * settings[:max_story_age] if settings[:hide_reviewed_stories] && !settings[:hide_read_stories]

        # fetch at least 30 stories to get a good shot at picking good stories!
        num_stories = 30 if num_stories < 30

        # fetch at most 200 stories
        num_stories = 200 if num_stories > 200
      end

#     max_stories_per_source = settings[:max_stories_per_source]
#     max_stories_per_source = nil if (max_stories_per_source == 0)

      story_type       = (params[:story_type].nil? || params[:story_type] == 'all') ? nil : params[:story_type]
      source_ownership = case params[:source_ownership]
        when nil, 'all' then nil
        when 'mainstream' then Source::MSM
        when 'independent' then Source::IND
        else params[:source_ownership]
      end
      base_opts = {
        :listing_type      => :mynews_active,
        :listing_type_opts => { :min_activity_score => (mynews_ordering == :most_relevant) ? MIN_ACTIVITY_SCORE : nil, 
                                :order_by           => MYNEWS_ORDERINGS[:mynews_active][mynews_ordering] },
#        :paginate         => true,
#        :page             => 1,
        :per_page          => num_stories,
#        :time_span         => settings[:max_story_age].days,
        :start_date        => Time.now - settings[:max_story_age].days,
        :end_date          => Time.now + 1.day,  # allow "future" stories to show up!
        :filters           => {
          :story_type      => story_type,
          :hide_read       => member && settings[:hide_read_stories] ? member.id : nil,
          :sources         => {
            :rating_class  => settings[:source_status],
            :media_type    => settings[:media_type],
            :ownership     => source_ownership,
#            :max_stories_per_source => max_stories_per_source
          }
        }
      }

      # Handle story rating setting specially!
      (min_reviews, min_story_rating, status) = case settings[:story_status]
        when nil, ""    then [nil, nil, nil] # Optimization where we check for status != hide rather than status = everything else
        when "posted"   then [nil, nil, [Story::LIST, Story::FEATURE]]
        when "reviewed" then [1,   nil, [Story::LIST, Story::FEATURE]]
        when "rated"    then [3,   nil, [Story::LIST, Story::FEATURE]]
        when "trusted"  then [3,   3.0, [Story::LIST, Story::FEATURE]]
      end
      base_opts[:filters][:min_reviews]      = min_reviews if min_reviews
      base_opts[:filters][:min_story_rating] = min_story_rating if min_story_rating
      base_opts[:filters][:status]           = status if status
      base_opts[:filters][:exclude_stories]  = params[:exclude_stories].split(",").map { |x| x.strip.to_i } if !params[:exclude_stories].blank?

      scores = {}
      tmp_stories = []
      story_matches = {}
      while (true) do
        all_stories = {}
        if params[:follow_type]
          item = params[:follow_type].capitalize.constantize.send("find", params[:follow_id])
          fetch_followed_stories(followed_items, {:type => params[:follow_type].to_sym, :item => item}, base_opts, all_stories, scores, story_matches)
        else
          fetch_followed_stories(followed_items, {:type => :feed},   base_opts, all_stories, scores, story_matches)
          fetch_followed_stories(followed_items, {:type => :source}, base_opts, all_stories, scores, story_matches)
          fetch_followed_stories(followed_items, {:type => :topic},  base_opts, all_stories, scores, story_matches)
          fetch_followed_stories(followed_items, {:type => :member}, base_opts, all_stories, scores, story_matches)
        end

        # Create the final list of stories by filtering out stories that:
        # - don't meet min. # of criteria (ignore num settings criteria if we are choosing from a specific followed item)
        # - I've reviewed (if I want reviewed stories hidden)
        l = all_stories.values
        l = l.reject { |s| story_matches[s.id][:count] < settings[:min_matching_criteria] } if !params[:follow_type]
        l = l.reject { |s| s.reviewed_by?(member) } if member && settings[:hide_reviewed_stories]
        tmp_stories += l

        # Sort the merged list by listing type specific ordering
        # Here, use 'rating' instead of sort_rating!  SSS FIXME: check with fab & david how to handle this.
        case mynews_ordering
          when :most_recent
            tmp_stories.sort! { |s1, s2|
              c = s2.sort_date  <=> s1.sort_date
#              c = story_matches[s2.id][:count] <=> story_matches[s1.id][:count] if (c == 0)
              c = scores[s2.id] <=> scores[s1.id] if (c == 0)
              c = s2.rating     <=> s1.rating  if (c == 0)
              c
            }
          when :most_trusted
            tmp_stories.sort! { |s1, s2|
              c = s2.rating     <=> s1.rating     
              c = s2.sort_date  <=> s1.sort_date if (c == 0)
#              c = story_matches[s2.id][:count] <=> story_matches[s1.id][:count] if (c == 0)
              c = scores[s2.id] <=> scores[s1.id]   if (c == 0)
              c
            }
          when :most_relevant
            tmp_stories.sort! { |s1, s2|
#              c = story_matches[s2.id][:count] <=> story_matches[s1.id][:count]
              c = scores[s2.id] <=> scores[s1.id]  # if (c == 0)
              c = s2.sort_date  <=> s1.sort_date if (c == 0)
              c = s2.rating     <=> s1.rating    if (c == 0)
              c
            }
        end

        stories = tmp_stories.first(num_reqd)

        # Most of the time, we will get what we want and bail!  If not, we will fetch stories once more and look for inactive stories
        break if (stories.length == num_reqd) || (mynews_ordering != :most_relevant) || (base_opts[:listing_type] == :mynews_inactive)

        # Try again -- this time, only with inactive stories!
        base_opts[:listing_type] = :mynews_inactive
        base_opts[:listing_type_opts] = { :max_activity_score => MIN_ACTIVITY_SCORE, :order_by => MYNEWS_ORDERINGS[:mynews_inactive][:most_relevant] }
      end

      { :stories => stories, :scores => scores, :matches => story_matches }
    end
  end

  def match_boost_factor(item_type, num_matches)
     # Each new matched item has progressively lower impact -- MATCH_DECAY_FACTORS[item_type]
    decay = MATCH_DECAY_FACTORS[item_type]
    ((1 - decay ** num_matches) / (1 - decay) * MATCH_BOOSTS[item_type])
  end

  def fetch_followed_stories(followed_items, follow_opts, base_opts, all_stories, scores, story_matches)
    item_type = follow_opts[:type]
    itype = "#{item_type}s".to_sym
    fitems = follow_opts[:item] ? [follow_opts[:item]] : followed_items[itype]  # Either a specific id or everything!
    if !fitems.blank?
      fids = fitems.map(&:id)

      # What I really need is a deep clone not a shallow clone!
      opts = base_opts.clone
      opts[:filters][:sources].delete(:ids) # get rid of source ids that get tacked on -- story listing code modifies its arguments!

      # IMPORTANT: Do not use opts[:filters].merge! -- this will modify the underlying base_opts hash
      opts[:filters] = opts[:filters].merge({"#{item_type}_ids".to_sym => fids}) 

      # SSS FIXME: local_site??  Is mynews subject to local site constraints?
      Story.list_stories_with_associations(opts, [:submitted_by_member, :sources, :tags, {:reviews => :member}, :feeds]).each { |s|
        sid = s.id
        all_stories[sid] = s
        all_matches = case item_type
#          # for topics, return only those matching subjects for which there isn't a matching topic
#          when :topic  then matches = fitems & s.send(itype); matches - matches.collect{ |m| m.class == Topic ? m.subjects : []}.flatten.uniq
          when :topic  then fitems & Topic.tagged_topics_or_subjects(s.topic_or_subject_tags)
          when :member then fitems & ((s.reviews.collect { |r| r.member }.compact) | [s.submitted_by_member])
          else              fitems & s.send(itype) 
        end
        num_matches = all_matches.length
        story_matches[sid] ||= {:count => 0}
        story_matches[sid][:count] += num_matches
        story_matches[sid][itype] = all_matches

        # NOTES:
        # 1. Boosting has to be multiplicative so that decay continues to have its effect on the story!
        #    So, stale stories are boosted by a lower value than newer stories
        # 2. Different followed items are boosted differently     -- MATCH_BOOSTS[item_type]
        # 3. Boost topics & subjects different (effectively, subject matches count lower than topic matches)
        # 4. Each new matched item has progressively lower impact -- MATCH_DECAY_FACTORS[item_type]
        if (item_type == :topic)
          num_subjects = all_matches.reject { |x| x.class != Subject }.length
          mbf = match_boost_factor(:subject, num_subjects) + match_boost_factor(:topic, num_matches - num_subjects)
        else
          mbf = match_boost_factor(item_type, num_matches)
        end
        scores[sid] ||= s.activity_score
        scores[sid] *= (1+mbf)
      }
    end
  end

  MYNEWS_DROPDOWN_SETTINGS_FIELDS = [
    [:stories_per_page, "Number of Stories"],
    [:max_story_age, "Story Date"],
    [:story_status, "Story Status"],
#    [:story_type, "Story Type"],
    [:source_status, "Source Status"],
#    [:max_stories_per_source, "Stories per Source"],
    [:media_type, "Source Medium"],
#    [:source_ownership, "Source Ownership"],
    [:min_matching_criteria, "Number of Matches"]
  ]

  MYNEWS_CHECKBOX_SETTINGS_FIELDS = [
    [:hide_reviewed_stories, "Hide stories I've reviewed"],
    [:hide_read_stories, "Hide stories I've read"],
#    [:mynews_homepage, "Make this my homepage"]
  ]

  def self.mynews_special_subjects
    @@mynews_special_subjects ||= Subject.site_subjects(nil, :conditions => {:slug => ["world","us","politics","business","scitech"]}, :order => "topics.id")
  end

  def config_mynews(member, my_page)
    @subject_list     = MynewsListing.mynews_special_subjects
    @followed_items   = followed_items_hash(member)
    @no_follows_yet   = @followed_items[:empty]
    settings          = mynews_settings(member, my_page)
    settings[:stories_per_page] = 25 if request.url =~ /.xml$/ # For RSS feeds, fetch 25 stories no matter what the settings are
    @mynews_opts      = OpenStruct.new(settings)
    res               = mynews_stories(params, @member, @followed_items, settings)
    @stories          = res[:stories]
    @scores           = res[:scores]
    @story_matches    = res[:matches]
  end

  def mynews_listing(member, settings_override = {})
    settings = mynews_settings(member)
    settings.merge!(settings_override)
    mynews_stories({}, member, followed_items_hash(member), settings)
  end
end
