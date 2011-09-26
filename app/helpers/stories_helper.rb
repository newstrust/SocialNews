module StoriesHelper
  include ApplicationHelper
  include ActionView::Helpers::TextHelper

  LISTING_TYPE = { "" => "", 
                   "most_recent"    => "Most Recent Stories", 
                   "most_trusted"   => "Most Trusted Stories",
                   "least_trusted"  => "Least Trusted Stories",
                   "all_rated_stories" => "All Rated Stories",
                   "for_review"     => "For Review",
                   "recent_reviews" => "Recent Reviews" }
  
  def display_status(status)
    SiteConstants::ordered_hash("story_status")[status]["passive_name"]
  end

  def default_timespan(ltype, page_obj)
    case ltype.to_s
      when "most_recent", "for_review", "all_rated_stories" then "all" 
      when "least_trusted" then LocalSite.least_trusted_date_window_size(@local_site)
      when "most_trusted"
        case page_obj
          when nil            then LocalSite.default_date_window_size(@local_site)
          when Topic, Subject then LocalSite.date_window_size_for_topic_listing(@local_site, page_obj)
          when Group          then page_obj.sg_attrs.listing_date_window_size
        end
      else
        LocalSite.default_date_window_size(@local_site)
    end
  end

  def display_status_badge(status)
    status = SiteConstants::ordered_hash("story_status")[status]["passive_name"]
    badge = status.downcase + "_badge"
    "<span class=\"#{badge}\">" + image_tag("/images/ui/story_listings/#{badge}.png", :alt => status) + "</span>"
  end

  def display_status_badge_newsletter(status)
    status = SiteConstants::ordered_hash("story_status")[status]["passive_name"]
    badge = status.downcase + "_badge"
    "<span style=\"width:42px;height:11px;margin:4px 0px 0px 5px;\">" + image_tag("#{home_url}images/ui/story_listings/#{badge}.png", :alt => status) + "</span>"
  end

  def find_queued_stories(local_site, opts)
    new_opts = { :listing_type => :queued_stories,
                 :page         => opts[:page]     || 1,
                 :per_page     => opts[:per_page] || 50,
                 :timespan     => opts[:timespan] || 1,
                 :t_slug       => opts[:t_slug]   || (opts[:topic_id] ? Topic.find(opts[:topic_id]).slug : nil),
                 :s_slug       => opts[:s_slug]   || (opts[:subject_id] ? Subject.find(opts[:subject_id]).slug : nil) }

      # Pass thru' incoming opts
    [:no_local, :listing_type_opts, :use_activity_score, :count_only, :max_stories_per_source, :all, :include, :exclude_stories, :paginate, :story_status, :source_ownership, :feed_id, :group_id].each { |k| new_opts[k] = opts[k] }
    Story.normalize_opts_and_list_stories_with_associations(local_site, new_opts)
  end

  def get_listing_title(opts)
    title = ""

      # 1. Story status types
    if (!opts[:story_status].blank?)
      title += '<span class="highlight">' + display_status(opts[:story_status]) + ' : </span>'
    end

      # 2. Topic/Subject/Group
    if !opts[:s_slug].blank?
      title += '<span class="topic">' + Subject.find_subject(opts[:s_slug], @local_site).name + '</span> - '
    elsif !opts[:t_slug].blank?
      title += '<span class="topic">' + Topic.find_topic(opts[:t_slug], @local_site).name + '</span> - '
    elsif !opts[:g_slug].blank?
      title += '<span class="topic">' + Group.find_by_id_or_slug(opts[:g_slug]).name + '</span> - '
    end

      # 3. Listing type
    listing_type = opts[:listing_type]
    title += '<span class="listing_type">' + LISTING_TYPE[listing_type] + '</span>'

    story_type  = opts[:story_type] || ""
    source_type = opts[:source_ownership] || ""

      # 4. Source
    specific_src = Source.find_by_slug(opts[:source]).name if !opts[:source].blank?
    if (!specific_src.blank?)
        # Name of the source
      so_str = specific_src
    else
        # Mainstream / Independent / Unrated Sources / Rated Sources / Trusted Sources / Untrusted Sources
      so_str  = source_type.capitalize
      so_str += " Sources" if (!source_type.blank? && source_type != "mainstream" && source_type != "independent")
    end

      # 5. Timespan
    timespan = ""
      # SSS FIXME: BUG: Not a valid title if there is a start date!
    sd = opts[:start_date] || opts[:review_start_date]
    ed = opts[:end_date] || opts[:review_end_date]
    if (opts[:timespan] && (opts[:timespan] != "all"))
      if sd
        timespan = " | #{opts[:timespan]} days from #{sd}"
      else
        timespan = " | Last #{opts[:timespan]} days"
      end
    elsif sd
      ed ||= Time.now.strftime("%Y.%m.%d")
      timespan = " | #{sd} - #{ed}"
    end

      # 6. Story Type & Source ownership
    none    = story_type.blank? && source_type.blank? && specific_src.blank?
    use_bar = !story_type.blank? && (!source_type.blank? || !specific_src.blank?)
    if none
      title += '<span class="content_type">' + timespan + '</span>' 
    else
      title += '<span class="content_type"> (' + story_type.capitalize + "#{' | ' if use_bar}" + so_str + timespan + ')</span>' 
    end

    return title
  end

  def get_rss_feed_title(listing_params, feed_cat)
        ## Set up the feed title
    feed_title = ""
    feed_title += case feed_cat
      when "media"    : listing_params[:listing_topic] + " Stories"
      when "topics"   : Topic.find_topic(listing_params[:t_slug], @local_site).name + " - "
      when "subjects" : Subject.find_subject(listing_params[:s_slug], @local_site).name + " - "
      when nil        : ""
    end
    
    listing_type = listing_params[:listing_type]
    feed_title += LISTING_TYPE[listing_type]
    if (listing_params[:source])
      feed_title = "#{feed_title} from #{listing_params[:source]}"
    else
        # Content type
      story_type = listing_params[:story_type]
      feed_title += ": " + Story::STORY_TYPE[story_type] if story_type && story_type != ""

        # Convert source_type to how it is expected to be (msm/ind)
      source_type  = listing_params[:source_ownership]
      so = Source::MSM if source_type && source_type == "mainstream"
      so = Source::IND if source_type && source_type == "independent"
      feed_title += " (" + Source::OWNERSHIP[so] + ")" if so && so != ""
    end

    return feed_title
  end

    ## FIXME: Cannot compute home_url here without access to url writer .. so, passing it in instead
  def widgetize_listing(widget_params, listing_stories, add_member_review = false, add_diggs_and_tweets = false)
    listing_url   = widget_params[:listing_url]
    listing_type  = widget_params[:listing_type]
    listing_topic = widget_params[:listing_topic]
    # title_prefix exists to deal with groups, local sites, and all the other requirements that migh surface
    # eventually, maybe swallow listing_topic into it as well?
    title_prefix  = widget_params[:title_prefix]  
    story_type    = widget_params[:story_type]
    source_type   = widget_params[:source_ownership]
    timespan      = widget_params[:timespan]

      # Convert source_type to how it is expected to be (msm/ind)
    so = source_type
    so = Source::MSM if source_type && source_type == "mainstream"
    so = Source::IND if source_type && source_type == "independent"

    return {
      :metadata => {
        "local_site"    => widget_params[:local_site],
        "site_base_url" => home_url,
        "listing_url"   => listing_url,
        "title_prefix"  => title_prefix || "",
        "listing_topic" => listing_topic,
        "listing_type"  => LISTING_TYPE[listing_type] || "",
        "timespan"      => (timespan.blank? ? "" : "#{timespan} days"),
        "hdr_story_type"=> story_type ? Story::STORY_TYPE[story_type] : "",
        "sources_type"  => so ? Source::OWNERSHIP[so] : "",
        "source_name"   => widget_params[:source_name],
        "min_reviews"   => SocialNewsConfig["min_reviews_for_story_rating"]
      },
      :stories => listing_stories.collect { |s|
        sw = {
          "id"          => s.id,
          "story_type"  => humanize_token(s, :story_type),
          ## SSS FIXME: Pending stories have no story date.  But question is why are pending stories showing up here?
          "date"        => (s.story_date || Time.now).strftime("%Y/%m/%d"),
          "title"       => s.title,
          "url"         => s.url,
          "source"      => (!s.primary_source) ? "" : s.primary_source.format_for_widget,
            ## IMPORTANT: when zero, set it as "0.0", not as 0.0 so that this value is treated as non-null
          "rating"      => !s.rating ? "0.0" : sprintf("%0.1f", s.rating),
          "num_reviews" => "#{s.reviews_count}",  ## If 0, without quotes, the value will be treated as nil
          "authors"     => s.journalist_names,
          "quote"       => s.excerpt
        }
        if add_member_review && s.member_review
          mr = s.member_review
            # Replace standard story quote with the first story excerpt from the member -- get plain text
          sw["quote"] = mr.excerpts[0].body(:plain) if !mr.excerpts.blank?
          rs = s.story_relations.reject { |r| r.related_story.nil? || r.member_id != mr.member.id || r.related_story.status == Story::HIDE }[0..1]
          sw.merge!({"review" => { 
                        "id"      => mr.id,
                        "rating"  => !mr.rating ? "0.0" : sprintf("%0.1f", mr.rating),
                        "note"    => mr.comment,
                        "comment" => mr.personal_comment,
                            # collect related links (at most 2)
                        "links"   => rs.blank? ? nil : rs.collect { |r| {"url" => r.related_story.url, "title" => r.related_story.title} }
                    }})
        end
        if add_diggs_and_tweets
          nd = s.num_diggs
          nt = s.num_tweets
          t1 = s.metadata_update_time(:digg)
          t2 = s.metadata_update_time(:tweetmeme)
          buf = "("
          t = nil
          if nd && (nd > 0)
            buf += pluralize(nd, "digg")
            t = t1
          end
          if nt && (nt > 0)
            buf += ", " if nd && (nd > 0)
            buf += pluralize(nt, "tweet")
            t = t2 if (!t || t2 < t1)
          end
          sw["digg_tweet_info"] = (nd && (nd > 0)) || (nt && (nt > 0)) ? buf + ")" : ""
          sw["via_credits"] = show_abbreviated_feed_attribution(s, 75, {}, true)
        end

        sw
      }
    }
  end

  # This method checks whether the cached fragment is expired or not.
  # If expired, it yields control to a block to fetch new story listings (the last statement of the block should have computed story listings!)
  # In either case, it returns a list of story ids that were cached.
  def get_cached_story_ids_and_when_fragment_expired(cached_fragment_name, expiration_time_in_secs)
    if (ActionController::Base.cache_configured?)
      frag_expired = false
      when_fragment_expired(cached_fragment_name, expiration_time_in_secs.from_now) do
        frag_expired = true
      end

      story_ids_file = "#{FILE_CACHE_STORE_DIR}/views/#{cached_fragment_name}.story_ids"
    else
      story_ids_file = nil
      frag_expired = true
    end

    ## FIXME: Potential (but unlikely) race condition scenario described here
    ##
    ## Fragment expiration time: T
    ##
    ## thread 1: arrives at time T - 1 and finds that the fragment is not expired and goes to the else part.
    ##           and for some godforsaken reason, wastes time playing poker on the internet before going to
    ##           the view code at time T + 3
    ##
    ## thread 2: arrives at time T + 1 and finds that the fragment is expired and expires the cache fragment
    ##           at time T + 2 and rebuilds the new fragment at time T + 50 (so, in between T+2 and T+50,
    ##           there is no cached fragment)
    ##
    ## now, thread 1 goes to the view code and will not find any cached fragment and tries to render the code
    ## and will crash with a nil object because it won't find any stories -- because it gambled away all its 
    ## cached stories playing poker on the internet
    ##
    ## Well, how likely is this scenario?  Not sure ... But, we can detect this scenario in the view code
    ## (@stories is nil and @will_be_cached is false) and take corrective action.

    if (frag_expired)
        ## If cached fragment has expired, build the list of stories by yielding to the code block 
        ## Then write this new list to disk
      cached_story_ids = yield
      File.open(story_ids_file, "w") { |f| f.write(cached_story_ids * " ") } if story_ids_file
    else
        ## Read the list of story ids from disk
      data = ""
      File.open(story_ids_file, "r") { |f| data = f.read }
      cached_story_ids = data.split(/\s/).collect { |x| x.to_i }
    end

    return cached_story_ids
  end

  def save_link_function_options(story, options={})
    { :url      => save_story_url(story, :format => "js", :ref => options[:ref]),
    	:before   => "var save_link = this; $(save_link).pulse(true)",
    	:complete => "update_save_link(save_link, request)",
    	:method   => :post }
  end

  # Generate ajaxy "Star" links
  #
  # Options:
  #   :cached - must be TRUE if link is in a cached block!
  #   :class, :style - can be used as usual
  #
  # NOTE: copy changes here must be made in application.js as well!!!
  def link_to_star(story, options={})
    options[:class] ||= "starred"
    # This will save us an extra db call / story to check for saved state
    # when we are dealing with cached story listings
    starred = (options[:cached] || !logged_in?) ? false : story.saved_by?(current_member)
    options[:class]   += " save_link" + (starred ? " on" : "")
    options[:story_id] = story.id # to provie JS access to all star links for this story on the same page
    options[:title]    = starred ? "Click here to unstar this story" : "Click here to star this story"
    options[:onclick]  = "return toggle_star(this, {id: #{story.id}, ref: '#{options[:ref]}'})" if logged_in?
    star_url = options[:ref] ? save_story_url(story, :ref => options[:ref]) : save_story_url(story)
    return link_to("", star_url, options)
  rescue ActionController::InvalidAuthenticityToken => e
    return "" if visitor_is_bot
    raise e
  end

  # Options:
  #   :cached - must be TRUE if link is in a cached block!
  #   :class, :style - can be used as usual
  #
  def link_to_save(story, options={})
    link_to_star(story, options)
  end

  def sort_feeds_by_type_and_feed_level(feeds)
    feeds.sort { |a, b|
      if a.nil? || b.nil?  
        logger.error "Nil feed found!" 
        return 0
      end

        # - Public non-user twitter feeds appear before member twitter feeds
        # - Regular feeds appear next
        # - Member Twitter feeds appear before facebook feeds
        # - Facebook newsfeeds appear last
        # Within each category, feeds are sorted randomly to give different feeds a chance to get displayed!
      if a.is_nonmember_twitter_feed?
        b.is_nonmember_twitter_feed? ? rand_sort_value : -1
      elsif b.is_nonmember_twitter_feed? 
        1
      elsif a.is_regular_feed?
        b.is_regular_feed? ? rand_sort_value : -1
      elsif b.is_regular_feed?
        1
      elsif a.is_twitter_feed?
        b.is_twitter_feed? ? rand_sort_value : -1
      else
        b.is_twitter_feed? ? 1 : rand_sort_value
      end
    }
  end

  def show_submitted_by(story, opts={}, link_options={})
    opts[:via_credits] = true if opts[:via_credits].nil?
    opts[:for_newsletter] = false if opts[:for_newsletter].nil?
    opts[:absolute_urls] ||= false
    opts[:prefix] ||= "Posted by"
    opts[:newsletter_prefix] ||= "from"
    opts[:followed_members] ||= []

    for_newsletter = opts[:for_newsletter]
    prefix = for_newsletter ? opts[:newsletter_prefix] : opts[:prefix]

    submitter_id = story.submitted_by_member.nil? ? nil : story.submitted_by_member.id

    if opts[:via_credits] && !story.feeds.blank? && (Member::ACTIVE_STAFF_IDS.include?(submitter_id) || submitter_id == Member.nt_bot.id)
      f = sort_feeds_by_type_and_feed_level(story.feeds)[0]
      # No links to facebook news feeds!
      fname = f.display_name
      for_newsletter ? "via #{fname}" \
                     : (f.is_private? ? "via #{fname}" \
                                      : "via #{link_to(fname, opts[:absolute_urls] ? feed_path(f) : feed_url(f), link_options)}")
    elsif submitter_id && (submitter_id == Member.nt_anonymous.id)
			"#{prefix} Guest Reviewer"
    elsif submitter_id && (submitter_id != Member.nt_bot.id)
      if opts[:followed_members].include?(story.submitted_by_member)
        link_options[:class] ||= ""
        link_options[:class] += " following"
      end
      for_newsletter ? "#{prefix} #{s(story.submitted_by_member.name)}" \
                     : "#{prefix} #{link_to_member(story.submitted_by_member, link_options, :absolute_urls => opts[:absolute_urls])}"
	  else
			"#{prefix} #{SocialNewsConfig["app"]["name"]}"
		end
  end
  
  def show_reviewers(story, opts={})
    unless story.reviews.empty?
      opts[:prefix] ||= "Reviewed by"
      opts[:followed_members] ||= []
  
      prefix = opts[:prefix]
      followed_members = opts[:followed_members]
      prefix + " " + story.reviews.collect { |r| 
        link_to_member(r.member, :class => (followed_members.include?(r.member) ? "following" : "" )) if r.member
      }.compact.join(", ")
    end
  end

  def show_feed_info(story, opts={}, link_options={})
    opts[:followed_feeds] ||= []
    opts[:absolute_urls] ||= false
    opts[:for_newsletter] ||= false
    feed_att = show_feed_attribution(story, 200, link_options, :absolute_urls => opts[:absolute_urls], :followed_feeds => opts[:followed_feeds], :for_newsletter => opts[:for_newsletter])
    feed_info = feed_att.blank? ? "via #{SocialNewsConfig["app"]["name"]}" : feed_att
    if !opts[:for_newsletter]
      diggs = story.num_diggs; tweets = story.num_tweets
      sep = feed_info.blank? ? "" : " - "
      if diggs and diggs>0
        feed_info += sep + plural(diggs,"digg"); sep = ", "
      end
      feed_info += sep + plural(tweets,"tweet") if tweets and tweets>0
    end
    return feed_info
  end

  def show_topics(story, opts={})
    opts[:prefix] ||= ""
    opts[:sufix] ||= ""
    opts[:separator] ||= " | "
    opts[:followed_topics] ||= []
    prefix = opts[:prefix]
    sufix = opts[:sufix]
    sep = opts[:separator]
    topics = Topic.tagged_topics_or_subjects(story.topic_or_subject_tags, @local_site)
    belongs_to_site = story.belongs_to_site?(@local_site)
    topic_str = topics.map {|t|
      link_to(h(t.name), 
              belongs_to_site ? t : "#{LocalSite.national_site}#{t.class == Topic ? topic_path(t) : subject_path(t)}",
              :class => (opts[:followed_topics].include?(t) ? "following#{popup_check}" : "#{popup_check}"))
    }.join(sep)

     if !belongs_to_site
       sufix = "<div class='warning'>Note: Clicking on the topics above will take you to our national site.</div>"
     end

    return prefix + topic_str + sufix unless topic_str.blank?
  end

  def show_abbreviated_feed_attribution(story, max_len=100, link_options={}, text_only=false)
    if !story.feeds.blank?
      sorted_feeds = sort_feeds_by_type_and_feed_level(story.feeds)
      h = {}
      len = 0
      links = [] 
      sorted_feeds.each { |f| 
          # Don't duplicate feed names!
        fname = f.display_name
        next if h[fname]
        h[fname] = f

          # Max 100 chars!
        len += fname.length
        break if len > (max_len-5)

          # All okay -- tack it on
        links << (text_only || f.is_private? ? fname : link_to("#{fname}", f, link_options))
      }
      "via #{links * ', '}#{len > (max_len-5) ? " ..." : ""}"
    end
  end

  def show_feed_attribution(story, max_len=100, link_options={}, opts={})
    opts[:absolute_urls] ||= false
    opts[:for_newsletter] ||= false
    if !story.feeds.blank?
      sorted_feeds = sort_feeds_by_type_and_feed_level(story.feeds)
      opts[:followed_feeds] ||= []
      save_link_class = link_options[:class]
 
        # We want max of max_len chars here ...
      len = 0
      links = [] 
      sorted_feeds.each { |f| 
        fname = f.display_name
        len += fname.length

        following_class = opts[:followed_feeds].include?(f) ? " following" : ""
        link_options[:class] = "#{save_link_class}#{following_class}"

        if !f.subtitle.blank? 
          len += f.subtitle.length + 4
          break if len > (max_len-5)

          link_txt = "#{fname} (#{f.subtitle})"
          links << (f.is_private? ? "<span class='#{following_class}'>#{link_txt}</span>" \
                                  : link_to(link_txt, opts[:absolute_urls] ? feed_url(f) : feed_path(f), link_options))
        else
          break if len > (max_len-5)

          links << (f.is_private? ? "<span class='#{following_class}'>#{fname}</span>" \
                                  : link_to(fname, opts[:absolute_urls] ? feed_url(f) : feed_path(f), link_options))

          break if opts[:for_newsletter]  # only one feed listed for newsletters
        end
      }
      "<span>via #{links * ', '}#{len > (max_len-5) ? " ..." : ""}</span>"
		end
  end

  def link_to_feed(f, link_options={}, opts={})
    opts[:mynews_truncate] ||= false
    fname = f.display_name
    if !f.subtitle.blank? 
      link_to(opts[:mynews_truncate] ? truncate("#{fname} (#{f.subtitle})",40,40) : "#{fname} (#{f.subtitle})", f, link_options)
    else
      link_to(opts[:mynews_truncate] ? truncate("#{fname}",40,40) : "#{fname}", f, link_options)
    end
  end
  

  # We still want nice ajax links in story listings, but we can burn member-specific ajax links
  # into templates that may be cached, hence the running through hoops here to enable
  # js functionality on domready
  #
  def member_cached_stories_state(story_ids)
    member_stories_state = {}
    if logged_in? and story_ids
        # Collect starred & review state in a single query rather than querying one story at a time
        # For home page, this eliminates 40 db queries -- also only pull the story id field
      find_opts        = {:select => "story_id", :conditions => {:member_id => current_member.id, :story_id => story_ids}}
      reviewed_stories = Review.find(:all, find_opts).map(&:story_id)
      starred_stories  = Save.find(:all, find_opts).map(&:story_id)

        # Output the starred & reviewed state as a json object
      story_ids.each do |s_id|
        member_stories_state[s_id] = {
          :reviewed => !reviewed_stories.grep(s_id).blank?,
          :saved    => !starred_stories.grep(s_id).blank?
        }
      end
    end
    return member_stories_state
  end

  def see_reviews_link_text(story, no_html = false)
    if (story.reviews_count == 0)
      txt = "See Info"
    elsif (story.reviews_count < SocialNewsConfig["min_reviews_for_story_rating"])
      txt = (story.reviews_count == 1) ? "See Review" : "See Reviews"
    else
      txt = pluralize(story.reviews_count, "Review")
    end

    txt += (no_html ? " >>" : " &raquo;")
    txt.gsub(/ /, "&nbsp;") unless no_html
  end

  def landing_page_subsection_title(listing_type, story_type, num_days)
    num_days = LocalSite.least_trusted_date_window_size(@local_site) if listing_type == :least_trusted
		if [:most_trusted,:least_trusted].include?(listing_type.to_sym)
      #period_txt = num_days <= 7 ? "week" : (num_days <= 30 ? "month" : (num_days <= 90 ? "quarter": (num_days <= 180 ? "semester" : "year")))
			#"#{listing_type.to_s.titleize} #{story_type.titleize}" + " <span style=\"color:#888;font-size:11px;\">(this #{period_txt})</span>"
			"#{listing_type.to_s.titleize} #{story_type.titleize}" + " <span style=\"color:#888;font-size:11px;\">(#{pluralize(num_days, "day")})</span>"
		else
			"#{listing_type.to_s.titleize} - #{story_type.titleize}"
		end
  end

  def subsection_title(page_obj, listing_type, story_type, source_ownership)
    opts = { :listing_type => listing_type }
    case page_obj
      when Topic   then opts[:t_slug] = page_obj.slug
      when Subject then opts[:s_slug] = page_obj.slug
      when Group   then opts[:group]  = page_obj
    end

    num_days = StoryListingHelpers.default_date_window_size(@local_site, opts)
		if [:most_trusted,:least_trusted].include?(listing_type.to_sym)
			"#{story_type.to_s.upcase} #{source_ownership.titleize}" + " <span style=\"color:#888;font-size:11px;\">(#{pluralize(num_days, "day")})</span>"
		else
			"#{story_type.to_s.upcase} - #{source_ownership.titleize}"
		end
  end

  def record_click_ajax_code(story)
    if (visitor_is_bot?)
      ""
    else
      ajax_params = "{url:'/stories/#{story.id}/record_click.js?', type:'post', data:'authenticity_token=#{form_authenticity_token}', dataType:'script'}"
      "$.ajax(#{ajax_params}); "
    end
  end

  def discuss_topics_for(story)

    # Will return a multi-dimensional array where the first value is the commentable_id and the second value is the number of comments
    # Once returned we sort by the total number of comments and then get the top three.
    subject_ids = Comment.count(:group => "commentable_id", :conditions => { :commentable_type =>'Topic', :commentable_id => story.subjects(@local_site).map(&:id) }).sort{ |a,b| b[1] <=> a[1] }.to_a[0..0]
    topic_ids   = Comment.count(:group => "commentable_id", :conditions => { :commentable_type =>'Topic', :commentable_id => story.topics(@local_site).map(&:id) }).sort{ |a,b| b[1] <=> a[1] }.to_a[0..2]
    source_ids  = Comment.count(:group => "commentable_id", :conditions => { :commentable_type =>'Source', :commentable_id => story.sources.map(&:id) }).sort{ |a,b| b[1] <=> a[1] }.to_a[0..0]

    return '' if subject_ids.empty? && topic_ids.empty? && source_ids.empty?
    arr = []

    subjects = Subject.find(:all, :conditions => { :id => subject_ids.map(&:first) })
    subject_ids.each do |a|
      record = subjects.detect{|x| x.id == a[0] }
      arr << "#{link_to(record.name, subject_path(record)<<'#comment_filter')}&nbsp;<span class='count'>(#{a[1]})</span>" if record
    end

    topics = Topic.find(:all, :conditions => { :id => topic_ids.map(&:first) })
    topic_ids.each do |a|
      record = topics.detect{|x| x.id == a[0] }
      arr << "#{link_to(record.name, topic_path(record)<<'#comment_filter')}&nbsp;<span class='count'>(#{a[1]})</span>" if record
    end

    sources = Source.find(:all, :conditions => { :id => source_ids.map(&:first) })
    source_ids.each do |a|
      record = sources.detect{|x| x.id == a[0] }
      arr << "#{link_to(record.name, source_path(record)<<'#comment_filter')}&nbsp;<span class='count'>(#{a[1]})</span>" if record
    end

    "Related Comments: " + arr.flatten.join('<span style="font-weight:normal"> | </span>')
  end

  def mass_update_stories(stories)
    stories.keys.inject("") { |notices, s_id| 
      s = Story.find(s_id)
      s_attrs = stories[s_id]

        # Try to delete the story -- can fail in some cases
      if (s_attrs[:status] == 'delete')
        begin
          surl = s.url
          s.destroy
          notices += "DELETED: <a style=\"color:#00a\" href=\"#{surl}\">#{s_attrs['title']}</a><br>"
        rescue Exception => e
          notices += "<span style=\"color:red\">Cannot delete story</span> (url=#{surl}, title=#{s_attrs['title']})! #{e}<br/>"
        end

          # Next story!
        next notices
      end

        # Check if the new url entered by the editor is kosher
      if (s_attrs[:url] != s.url)
        s2 = Story.check_for_duplicates(s_attrs[:url])

          # Reject the modified url if there is a different story with that url
        if s2 && (s2.id != s_id.to_i)
          notices += "<span style=\"color:red\">URL UNCHANGED!</span> For story <a style=\"color:#00a\" href=\"#{story_url(s)}\">#{s_attrs['title']}</a>, rejecting the new url you provided (#{s_attrs[:url]}) because there is already an existing story with that url (<a style=\"color:#00a\" href=\"#{story_url(s2)}\">#{s2.title}</a>)<br>"
          s_attrs[:url] = s.url
        end
      end

      orig_status = s.status
      review_attrs = s_attrs.delete(:review)

        # Attribute the story submission to the editor 
      s_attrs[:submitted_by_member] = current_member if s_attrs[:status] == Story::LIST

        # Save all attributes
      begin
        # s.local_site = @local_site # Set local site on which the story is being updated!
        s.attributes = s_attrs
        s.set_story_scope("not_sure", @local_site)
        s.save!
        ActivityScore.boost_score(s, :story_listed, {:member => current_member, :url_ref => "ame"}) if s.is_public?
      rescue ActiveRecord::StatementInvalid => e
        # As a guard against bugs
        logger.error "#{e}; Possible duplicate tagging attempted! Catching and ignoring exception; Original attrs: #{s_attrs.inspect}"
        begin
          s_attrs[:taggings_attributes] = dedupe_tagging_attrs(@story, s_attrs[:taggings_attributes]) if s_attrs[:taggings_attributes]
          s.attributes = s_attrs
          s.set_story_scope("not_sure", @local_site)
          s.save!
        rescue Exception => e
          notices += "<span style=\"color:red\">ERROR: Failed to save story #{s.id}.  Got exception #{e}.</span>"
          next notices
        end
      rescue Exception => e
        notices += "<span style=\"color:red\">ERROR: Failed to save story #{s.id}.  Got exception #{e}.</span>"
        next notices
      end

        # Feedback to the editor if he/she requested the story to be listed
      if s.is_public? && s_attrs[:status] == Story::LIST
        # SSS: Feb 15, 2011: We will blindly accede to editorial requests
        # if s.can_be_listed?
        if true
          notices += "LISTED: <a style=\"color:#00a\" href=\"#{story_url(s)}\">#{s_attrs['title']}</a>"
          missing_fields = s.empty_field_list
          if !missing_fields.empty?
            friendly_names = {"authorships" => "sources", "topic_or_subject_taggings" => "topics" }
            update_errors = missing_fields.map { |a| friendly_names[a] || a }
            notices += " <span style='color:red'>but it is missing #{update_errors * ', '}.</span>"
          end
          notices += "<br/>"

            # Create the mini-review, if appropriate
          if review_attrs[:add_review]
            r = current_member.story_review(s)
            if r.nil?
              r = Review.new(:story => s,
                             :member => current_member,
                             :status => Status::LIST,
                             :rating_attributes => review_attrs[:rating_attributes],
                             :comment => review_attrs[:comment])
              r.save_and_process_with_propagation
            else
              notices += "<span style=\"color:red\">Ignoring mini review</span> for story <a style=\"color:#00a\" href=\"#{story_url(s)}\">#{s_attrs['title']}</a>!  You have #{link_to("reviewed", r)} this story already.<br>"
            end
          end
        else
            ## Set status to what it was (pending/queued), if required fields are not all present
          s.status = orig_status
          s.save
          notices += "IGNORING LIST REQUEST for <a style=\"color:#a00\" href=\"#{story_url(s)}\">#{s_attrs['title']}</a> -- All required fields are not filled in!<br>"
        end
      end

      notices
    }
  end

  def dedupe_tagging_attrs(story, tagging_attrs)
    h = {}
    new_taggings = []
    # normalize names by stripping white space & ignoring case
    story.tags.each { |t| h[t.name.strip.upcase] = true }
    tagging_attrs.each { |ta|
      ta["name"].strip!
      ta["name"].upcase!
      if (ta["should_destroy"] == "false") && h[ta["name"]].nil?
        h[ta["name"]] = true
        new_taggings << ta
      end
    }

    new_taggings
  end
end
