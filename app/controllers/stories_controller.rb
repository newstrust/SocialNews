class StoriesController < ApplicationController
  include ApplicationHelper
  include StoriesHelper
  include FacebookConnectHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  protect_from_forgery :except => [ :feed_fetcher_post ]

  # Conditionally cache JSON & XML listing requests
  # On national site, cache page; On local sites, cache action -- to prevent caching conflicts 
  # caches_page   :index, :if => Proc.new { |c| c.cacheable?(true) }  
  caches_action :index, :if => Proc.new { |c| c.cacheable?(false) }, :cache_path => Proc.new { |c| "#{c.request.host_with_port}#{c.request.request_uri}" }

  def cacheable?(natl_site)
    fmt = request.format
    # Caution! It might seem that !c.request.format.html? should work ... but, if we get in an invalid format, that check will succeed!
    # ((natl_site && @local_site.nil?) || (!natl_site && !@local_site.nil?)) && (fmt.js? || fmt.json? || fmt.xml? || fmt.rss?)
    fmt.js? || fmt.json? || fmt.xml? || fmt.rss?
  end

  before_filter :login_required, :except => [:index, :show, :post, :feed_fetcher_post, :create, :toolbar]
   # we enforce our own rules in edit so that hosts can get through
  all_access_to :only => [:edit, :update]
  
  @@popup_actions = ["new", "edit_pending", "create"]
  cattr_reader :popup_actions

  @@story_listings_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["story_listings"]
  
  # story listing url layouts:
  #
  # 1. Main listings:     <BASE_URL>/stories/:listing_type/*
  # 2. Topic listings:    <BASE_URL>/topics/:slug/:listing_type/*
  # 3. Subject listings:  <BASE_URL>/subjects/:slug/:listing_type/*params*
  #
  # <BASE_URL>    -- http://socialnews.net / http://localhost:3000 / ...
  # :listing_type -- one of most_recent, most_trusted, worst, for_review, recent_reviews
  # :slug         -- topic slug
  # *params*      -- zero or more of the following key-value pairs (suitable defaults will be picked for each of these)
  #
  #    source=...            -- source slug
  #    content_type=...      -- video / audio
  #    story_type=...        -- news / opinion
  #    story_status=...      -- hide / list / feature / queue
  #    source_ownership=...  -- mainstream / independent
  #    media_type=...        -- newspaper / blog / online / ...
  #    edit_priority=...     -- minimum editorial priority
  #    start_date=yyyy.mm.dd -- start date from which to fetch news
  #    end_date=yyyy.mm.dd   -- end date till which to fetch news (must be > start-date)
  #    per_page=...          -- number of stories per page
  #    page=...              -- what page to fetch
  #
  # Examples:
  #
  # - http://socialnews.net/stories/most_recent
  # - http://socialnews.net/subjects/politics/for_review
  # - http://socialnews.net/topics/environment/recent_reviews&source=nytimes
  # - http://socialnews.net/stories/most_trusted?story_type=news&source_ownership=mainstream&per_page=50&page=2
  #
  # URL cleanup: We now allow story_type and source_ownership params to be directly included in the url as follows:
  #
  # - http://socialnews.net/stories/most_trusted/news/mainstream
  # - http://socialnews.net/subjects/politics/for_review/opinion
  # - http://socialnews.net/topics/environment/recent_reviews/independent
  #
  # The rest of the params have to be provided as &name=value pairs 
  # Main 'Full Story Listing' call; note that that templates are available for html, rss & js(on)

  def index
    # We won't support requests for GET /stories!
    # GET /stories.js gets cached and this conflicts with POST /stories.js which is used 
    # for posting new stories via ajax (toolbar related links, navbar post)
    # Since all story listings have a corresponding listing type in our setup, we'll simply reject these requests
    render_404 and return if params[:listing_type].nil?

    if (params[:source])
      @source = Source.find_by_slug(params[:source])
      raise ActiveRecord::RecordNotFound, "Page not found" if @source.nil?
      redirect_to access_denied_url and return unless @source.is_public? || (current_member && current_member.has_role?("admin"))
    end

    params[:listing_type] ||= "most_recent" # for default route

      # Get rid of the :method param
    params.delete(:method)

      # Extract timespan from the most-trusted/least-trusted listing type
    if (params[:listing_type] =~ /most_trusted_(\d+)/)
      params[:timespan] = $1
      params[:listing_type] = "most_trusted"
    elsif (params[:listing_type] =~ /least_trusted_(\d+)/)
      params[:timespan] = $1
      params[:listing_type] = "least_trusted"
    end

    respond_to do |format|
      format.html { output_html }
      format.json { output_json }
      format.js   { output_json }
      format.rss  { output_rss }
      format.xml  { output_rss }
    end
  rescue Exception => e
    logger.error "Bad request! Request uri is #{request.request_uri}.  Caught exception #{e}\n #{e.backtrace * '\n'}"
    render_404 and return
  end

  def activity_listing
    @url_tracking_key = "al"
    @stories = Story.normalize_opts_and_list_stories(@local_site, :listing_type => :activity_listing, :timespan => 3, :story_status => params[:status], :per_page => 50)
  end

  def info
    redirect_to :action => :show, :id => params[:id], :no_redirect => true
  end

  def new
    raise "Unexpected entry into new!  Investigate!"
  end

  # Full Story Admin form (basic metadata editing can be done from toolbar)
  #
  def edit
    @story = Story.find(params[:id])
    render_403(Story,"for editing") and return unless logged_in? && current_member.has_story_edit_privileges?(@story) 
    @story = Story.find(params[:id])
  end

  def show
    @url_tracking_key = params[:ref]  # Pass through url tracking code

    @story = Story.find(params[:id], :include => {:reviews => [:member], :related_stories => [:submitted_by_member]})
    if (@story && !@story.is_public? && !params[:no_redirect])
      s = Story.find(:first,
                     :joins      => "JOIN story_urls ON stories.id=story_urls.story_id",
                     :conditions => ["story_urls.url = ?", @story.url])
      redirect_to :action => :show, :id => s.id and return if !s.nil?
    end

    if @story.is_unpublished?
      flash[:warning] = "This story comes from one of our feeds. Its story info has been automatically filled in and may be incomplete or incorrect."
      link_str = render_to_string(:inline => "<%= link_to 'edit this story info', edit_story_url(@story) %>")
      flash[:warning] += "<br/> If you see any errors, please #{link_str}." if logged_in? && current_member.has_story_edit_privileges?(@story)
      @no_bots = true
    end

    # Allow access only if:
    # (a) story is visible (queued, pending, listed, featured)
    # (b) story is not visible, but the current member submitted it
    # (c) story is not visible, but the current member has host or higher privileges
    m = current_member
    render_403(Story) && return unless @story.is_visible? || (logged_in? && (m.id == @story.submitted_by_id || m.has_role_or_above?(:host)))

    # reviews, double-sorted.
    @reviews = logged_in? ? (m.has_role?(:admin) ? @story.reviews : @story.public_reviews_for_owner(m)) : @story.public_reviews
    @reviews.sort!{|ry, rx| rx.member_rating <=> ry.member_rating}
    @reviews.sort!{|ry, rx| rx.is_featured ^ ry.is_featured ? rx.is_featured ? 1 : -1 : 0} # featured at the top
    @current_member_review = @reviews.detect{|r| r.member.id == m.id if !r.member.blank? } if logged_in?

    unless visitor_is_bot?
      begin
        PageView.create(:session_id => session.session_id, :viewable => @story)
      rescue Exception => e
          # Mostly like exceptions from mysql complaining about duplicates
          # - in the rare cases when simultaneous requests go to different to
          # two mongrels and they hit mysql at the same time
        logger.error "EXCEPTION: #{e}; #{e.backtrace * '\n'}"
      end
      ActivityScore.boost_score(@story, :nt_pageview, {:member => m, :url_ref => @url_tracking_key})
      @story.process_in_background
    end
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  # Toolbar
  def toolbar
    # Load up the story. Let user through so long as it's not HIDDEN
    #
    m = current_member
    @story = Story.find(params[:id])
    render_403(Story) and return unless @story.status != Story::HIDE or (logged_in? and m.has_role_or_above?(:host))

    # Check if we have any duplicate reviews that need processing (only if logged in!)
    @dupes = session[:dupe_reviews] if logged_in?

    # AF: NYT framebuster workaround.
    # SSS: I think NYT looks for its url in the window location (but why?) and it is sensitive to an exact match.
    # So, we are just piggybacking on NYT's own toolbar with this hack!
    # TODO: This source-specific conditional check should be in StoryAutoPopulator or CustomStoryProcessors or something.
    #
    if NetHelpers.get_url_domain(@story.url) =~ /nytimes.com/ and params[:url].nil?
      redirect_to(URI.unescape(url_for(params.merge(:url => @story.url)))) and return
      # alternate syntax: possibly faster but less robust
      # redirect_to(request.request_uri + "?url=#{@story.url}") and return
    end
    
    # Record story click
    StoryClick.record_click(params[:id], session)

    # Update activity score for non-bot visitors
    ActivityScore.boost_score(@story, :target_pageview, {:member => m, :url_ref => params[:ref]}) unless visitor_is_bot?
    
    # Set up the review object; if member is logged in, see if they've already reviewed
    # the story! If not, fire up a new object.
    #
    # Member runs the risk of creating a duplicate review if they happen to get here
    # without logging in first. Sorry guys.
    new_review_params = {:story => @story}

    params[:popup] = true if @story.has_embedded_video? && params[:embedded_video_link]

    if logged_in?
      @review = Review.find(:first, :conditions => {:member_id => m.id, :story_id => params[:id]})
      @source_review = @story.primary_source.source_review_by_member(@local_site, m) if @story.primary_source
      # in case there was no review
      new_review_params[:form_version] = m.preferred_review_form_version
    else
      # Create a new member object for use in the signup forms
      @member = Member.new
    end
    @review ||= Review.new(default_review_params.merge(new_review_params))

    # 1. Use the review form we've been asked to use via the url
    # 2. If none available from 1, use the signed in member's preferred version
    # 3. If none available from 2, use "rating:mini"
    if !params[:review_form].blank?
      @review.form_version = params[:review_form]
    else
      @review.form_version = m.preferred_review_form_version if logged_in?
      @review.form_version ||= "rating:mini"
    end
    @source_review ||= SourceReview.new

    # Render
    #
    # only trigger MdF if story has neither been edited by a human nor been reviewed yet!
    @lookup_on_ready = @story.edited_by_member.nil? && (@story.reviews_count == 0)
    if params[:popup]
      if user_has_ie6?
        @popup_error = "Your browser doesn't support the #{APP_NAME} toolbar.<br />Please <a href='http://www.microsoft.com/windows/internet-explorer/default.aspx' target='_blank'>upgrade</a> your Internet Explorer browser."
      elsif @story.from_framebuster_site?
        @popup_warning = "You are seeing this popup instead of the toolbar because this site doesn't support the #{APP_NAME} toolbar."
      end
      render :action => "toolbar_popup", :layout => "popup"
    elsif @story.from_framebuster_site? || user_has_ie6? || @story.is_pdf?
      # Either story, site, or browser is incompatible w/ toolbar; prompt user to click to get popup review form
      # We come here when someone manually enters a toolbar url for a story in the browser bar OR someone submits a framebuster story via the post form
      if user_has_ie6?
        no_toolbar_msg = "Your browser doesn't support the #{APP_NAME} toolbar.<br />Please <strong><a href='http://www.microsoft.com/windows/internet-explorer/default.aspx' target='_blank'>upgrade</a></strong> to a more recent version of Internet Explorer."
      elsif @story.is_pdf?
        no_toolbar_msg = "The #{APP_NAME} toolbar does not support pdfs."
      else
        no_toolbar_msg = "This site doesn't support the #{APP_NAME} toolbar."
      end
      popup_review_link = render_to_string(:inline => "<%= link_to('Click here to review this story in a popup window.', @story.url, :onclick => \"return open_popup('#{toolbar_story_path(@story)}?popup=true', $(this))\")%>")
      flash[:notice] = popup_review_link + "<br /><span style='text-transform:none;font-weight:normal;'>(#{no_toolbar_msg})</span>"
      flash.discard
      render(:text => "", :layout => "application")
    else 
      render :layout => false # Normal Toolbar
    end
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  # Submit Story
  #
  # If we have story url/info (i.e., from bookmarklet/button), we should just
  # pop the story in the db (as autopopulate would) and then open the popup toolbar,
  # not the regular toolbar.  Ostensibly, if someone is using a button or bookmarklet
  # to submit a story, they are already on the story page and there is no reason to open
  # the story once again with the toolbar.
  #
  # If we don't have a story url, display a blank page with the post panel open
  #
  def post
    # first, merge params[:story] and params, to support both buttons and bookmarklet
    story_params = merged_story_params

    if story_params[:url].blank?
      # Open the story post panel by default
      @show_post_panel = true
    else
      # No anonymous posts henceforth
      if !logged_in?
        flash[:notice] = "Please login to submit a story to #{APP_NAME}"
        redirect_to new_sessions_url and return
      end

      m = current_member

      if m.terminated?
        flash[:notice] = "Your account has been suspended and you cannot post any stories to the site.  Please email us if you have any questions."
        redirect_to home_url and return
      end

      if !m.can_post?
        # SSS FIXME: Using link_to in controllers is not possible without monkey patching and other workarounds.  So, just hand-generating the anchor link
        flash[:notice] = "Your account must be validated before you can post a story. To have your account validated, please review two stories on our site, then #{validation_email_url}.  <a target='_blank' href='/help/faq/member/#member_profile_why_validation'>Click here</a> to learn about account validation and member levels."
        redirect_to home_url and return
      end

      if !member_has_posting_quota?(m)
        flash[:notice] = "You can only post up to #{SocialNewsConfig["max_posts_per_day"]} stories per day."
        redirect_to home_url and return
      end

      StoryAutoPopulator.logger.info "STORY-POST: http params: #{request.env.inspect}; url: #{story_params[:url]}"

      # check if the story exists in our db already
      @story = Story.check_for_duplicates(story_params[:url])
      if @story.nil?
        # Now fetch what story metadata we can
        @story, extra_info = Story.autopopulate_fields(Story.new(story_params), params[:url])

        # Track source of posts -- either the buttons have a referrer code we provided (are we doing this?)
        # Or, we just use a generic "POST" code to capture explicit "/post?url=...", button, or bookmarklet posts
        @story.referrer_code = (params[:bookmarklet] == "1") ? "bml" : (params[:ref] || "nav")
      
        # Process topic and subject params and accept them as topics / subjects independent of how they are passed in.
        # Ex: If we pass in topic1=Politics and subject1=Energy, accept Politics as a subject and Energy as a topic
        # even though Politics is not a topic and Energy is not a subject
        (1..5).collect { |n|
          [ params["topic#{n}".to_sym], params["subject#{n}".to_sym] ].collect { |tag|
            Tag.find_by_name(tag, :conditions => "tag_type IS NOT NULL") if tag
          }
        }.flatten.compact.each { |t| @story.taggings << Tagging.new(:tag => t) }

        @story.save # FIXME: check return
      else
        # Track source of posts -- either the buttons have a referrer code we provided (are we doing this?)
        # Or, we just use a generic "POST" code to capture explicit "/post?url=...", button, or bookmarklet posts
        @story.referrer_code = ((params[:bookmarklet] == "1") ? "bml" : (params[:ref] || "nav")) + "_dup"
      end

        # If logged in and the story is unvetted, go to the edit form.
        # Logged out visitors always go to review to encourage guest reviews
        # For vetted stories, no need to go to the edit form
      opts = {:go => (logged_in? && @story.is_unvetted?) ? :edit : :review}
      opts[:popup] = true if params[:popup] == true     # Explicit popup request
      opts[:popup] = true if params[:bookmarklet] == 1  # We've come from the bookmarklet
      opts[:popup] = true if request.url =~ %r|#{APP_DEFAULT_URL_OPTIONS[:host]}(\:\d+)?/submit\?| # Legacy buttons/bookmarklets
      opts[:ref]   = @story.referrer_code
      redirect_to(toolbar_story_path(@story, opts))
    end
  end

  # POST -- posted by feed fetcher ruby scripts that run outside rails and post parsed feed stories
  # In future, this could be converted to an api call to let other sites add stories to the NT db programmatically.
  def feed_fetcher_post
    ## Protect against accidental posts from unverified sources
    render_404 and return unless params[:api_key] == FeedParser::FF_KEY

    add_af_entry = false
    feed_id   = params[:feed_id].to_i # IMPORTANT: Convert to integer!
    feed_cats = params[:feed_cats]
    [:api_key, :feed_id, :feed_cats, :action, :controller].each { |k| params.delete(k) }
    s = Story.check_for_duplicates(params[:url])
    if s.nil?
      params[:status]          = Story::PENDING     # set story in pending status
      params[:content_type]    = 'article'          # default content type
      params[:submitted_by_id] = Member.nt_bot.id   # ascribe submission to the bot!
      s = Story.new(params)
      s.dont_process = true                         # No processable processing please!
      status = (s.save(false)) ? :created : "404"   # No validations please!
    else
      # ignore title & description from the new feed!
      status = "200"
    end

    # No dupe feed entries for a story
    if status != "404" && feed_id && !s.feed_ids.include?(feed_id)  # This will be a dupe check for feed parser (but just being cautious!) 
      s.add_feed_tags(feed_cats.split("|"))
      s.feeds << Feed.find(feed_id) # s.feed_ids << feed_id doesn't work!
      afs = AutoFetchedStory.find_by_story_id(s.id)
      AutoFetchedStory.create(:story_id => s.id, :fresh_story => (status == :created)) if afs.nil?
    end

    render :inline => "#{s.id}", :status => status
  end

  # Create (AJAX: navbar post; related url post; POPUP: story post from popup forms)
  def create
    m = current_member
    error_msg = nil

    # No anonymous posts henceforth
    if !logged_in?
      error_msg = "Please login to submit a story to #{APP_NAME}"
    elsif m.terminated?
      error_msg = "Your account has been suspended and you cannot post any stories to the site.  Please email us if you have an questions."
    elsif !m.can_post?
      # SSS FIXME: Using link_to in controllers is not possible without monkey patching and other workarounds.  So, just hand-generating the anchor link
      error_msg = "Your account must be validated before you can post a story. To have your account validated, please review two stories on our site, then #{validation_email_url}.  <a target='_blank' href='/help/faq/member/#member_profile_why_validation'>Click here</a> to learn about account validation and member levels."
    elsif !member_has_posting_quota?(m)
      error_msg = "You can only post up to #{SocialNewsConfig["max_posts_per_day"]} stories per day."
    end

    story_params = merged_story_params
    if story_params[:url].blank?
      error_msg = "Received an empty url.  Please try again!"
    end

    if error_msg
      respond_to do |format|
        format.js {
          render :json => {:error => true, :validation_errors => error_msg } and return
        }
        format.html {
          flash[:error] = error_msg
          redirect_to new_sessions_url and return
        }
      end
    end

    # Check if we are trying to create an existing story -- ex: submitting a url that exists in the db with pending-status
    @story = Story.check_for_duplicates(story_params[:url])

    respond_to do |format|
      format.js {
        begin
          if @story.nil?

              # Get basic metadata (w/o querying APIs yet)
              # Note that since this is coming from the toolbar, the story will always remain in PENDING status
              # Till the member/visitor clicks Save on the edit form, the story will remain pending.
            @story, extra_info = Story.autopopulate_fields(Story.new(story_params), params[:url])

              # Track source of posts -- navbar / related link ajax posts
            @story.referrer_code = params[:related_story] == "1" ? "rel" : "nav"

              # The story auto populator might change the url, so check if there is a story in the db with the new url 
            if (@story.url != story_params[:url])
              existing_story = Story.check_for_duplicates(@story.url)
              @story = existing_story if !existing_story.nil?
            end

            # Do not accept stories that come from the same domain!
            if (@story.url =~ %r|#{APP_DEFAULT_URL_OPTIONS[:host]}(\:\d+)?/|)
              raise "ERROR: Couldn't resolve #{APP_NAME} story url #{@story.url} to the target story."
            end

            # Attempt to save if this is a new story! 
            if @story.id.nil?
              # SSS: NOTE: The story has not yet been saved to the database, so I have to use the in-memory taggings association rather
              # than use @story.tags which would fetch old info from the db!
              #
              # If the story is being submitted via a local site, automatically add the local site constraint tag!
              if @local_site && !@story.taggings.map(&:tag_id).include?(@local_site.constraint.id)
                @story.taggings << Tagging.new(:tag_id => @local_site.constraint.id, :member_id => current_member.id) 
              end

              if !@story.save
                logger.error "Validation errors for story #{@story.url}: #{@story.errors.full_messages * '\n'} ------ "
              end
            end
          else
            @story.referrer_code = "nav_dup"
          end

          render :json => {
            :id           => @story.id,
            :url          => @story.url,
            :title        => @story.title,
              # If logged in and the story is unvetted, go to the edit form.
              # Logged out visitors always go to review to encourage guest reviews
              # For vetted stories, no need to go to the edit form
            :toolbar_path => toolbar_story_path(@story, :go => (logged_in? && @story.is_unvetted?) ? :edit : :review, :ref => @story.referrer_code),
            :validation_errors => @story.errors.full_messages.join('<br/>') # if it failed to save, let client know why
          }
        rescue Exception => e # generic catch-all error case
          logger.error "EXCEPTION: #{e}; #{e.backtrace * '\n'}"
          render :json => {:error => true, :validation_errors => "INVALID URL (email #{SocialNewsConfig["email_addrs"]["help"]} if incorrect)"}
        end
      }
    end
  end
  
  # As of the Toolbar launch, this is now (sometimes) an ajax call.
  # Consider making a separate action for the toolbar ajax call, to keep logic cleaner.
  #
  # update story's meta info.
  # we also force user through this path if they tried to review a "pending" status story.
  #
  def update
    # Update member attributes upfront!
    m = current_member
    m.update_attributes(params[:member])
    @story = Story.find(params[:id])

    # Save/update image 
    update_image(@story, params)

    story_params = params[:story]

    # Save/update video 
    if params[:video]
      if @story.video
        @story.video.update_attributes(params[:video])
      elsif !params[:video][:embed_code].blank?
        story_params[:video] = Video.new(params[:video])
      end
    end

    # Check if we've ended up with 2 stories with the same url -- can happen because of bugs in front end js that traps double-clicks
    # If so, merge them intelligently, and redirect the member to the merged story!
    found_dupes = false
    @other_story = Story.find_by_url(@story.url, :conditions => ["id != ?", @story.id])

    # Merge them only if the stories are close together in ids.
    # We wont have stories with duplicate urls in other scenarios.
    # Those are errors and should be flagged as such.
    if @other_story && ((@other_story.id - @story.id).abs < 10)
      if @other_story.is_public?
        if @story.is_public?
            # Both stories are public!  No way to know what is the better story to pick.  But, since we have a captive member here,
            # retain the current story's settings, update the url to a dummy url, and move it to pending status.
            # This way, the story will be retained in the db for editors to look at!
            # The new dummy url is guaranteed to be unique!
          @other_story.update_attributes(:status => Story::PENDING, :url => "DUPE_URL:#{@other_story.id}:#{@story.id}")
          @other_story.reload
          @story.swallow_dupe(@other_story, m)
          @retained = @story
        else
          @other_story.swallow_dupe(@story, m)
          @retained = @other_story
        end
      else
        @story.swallow_dupe(@other_story, m)
        @retained = @story
      end
      logger.error "ERROR: While updating story #{params[:id]}, found dupe story for #{@retained.url}.  Merged them and retained #{@retained.id}."

      # Route generation is sensitive to nil values!  We cannot have nils!
      opts = {:go => :edit}
      opts[:ref]   = params[:ref] if params[:ref]
      opts[:popup] = params[:popup] if params[:popup]
      merged_story_path = toolbar_story_url(@retained, opts)
      found_dupes = true
      dupe_error = (m.preferred_edit_form_version == 'short') ? "" : "We found another story with the same url and have merged the two stories.<br/><br/>  <a style='font-weight:bold;color:green' href='#{merged_story_path}'>Click here to verify the merged information.</a>."

      # If we are overwriting the other story with the info from the form, ensure that
      # empty attributes don't clear out filled out attributes from that story!
      story_params.each { |k,v| story_params[k] = @retained.send(k) if v.blank? } if @retained != @story

      params[:id] = @retained.id
      @story = @retained
    end

    # Get existing params before the current info is overwritten below
    prev_story_status = @story.status
    was_public  = @story.is_public?
    submitter   = @story.submitted_by_member
    prev_editor = @story.edited_by_member

    # Pick the right story type from the expanded/condensed versions -- depends on the form version the member edited
    if story_params[:advanced_edit_form]
      story_params.delete(:advanced_edit_form)
      story_params[:story_type] = story_params.delete(:story_type_expanded)
    else
      st_expanded  = story_params.delete(:story_type_expanded)
      st_condensed = story_params.delete(:story_type_condensed)
      if @story.field_is_visible?(m, :story_type_expanded)
        story_params[:story_type] = st_expanded if st_expanded
      elsif @story.field_is_visible?(m, :story_type_condensed)
        # Default to opinion type for the short edit form if one is not provided
        if st_condensed.blank?
          story_params[:story_type] = "opinion" if (m.preferred_edit_form_version == "short")
        else
          story_params[:story_type] = st_condensed
        end
      end
    end

    # We cannot update story scope until taggings have been updated
    story_scope = (story_params.delete(:story_scope) || "").downcase

    # Update -- duplicate associations that cause exceptions are trapped
    @story.attributes = story_params.merge(last_edited_params)

      # NOTE: The attribute update above can lead to duplicate association exceptions (which are trapped)
      # Filter out duplicates in that case!
    if @story.found_duplicate_tagging_association || @story.found_duplicate_authorship_association
      @story.reload # Get a fresh copy of the story!

      # Process taggings!
      story_params[:taggings_attributes] = dedupe_tagging_attrs(@story, story_params[:taggings_attributes]) if story_params[:taggings_attributes]

      # Process authorships!
      if story_params[:authorships_attributes]
        h = {}
        new_authorships = []
        # normalize names by stripping white space & ignoring case
        @story.sources.each { |s| h[s.name.strip.upcase] = true }
        story_params[:authorships_attributes].each { |aa|
          aa["name"].strip!
          aa["name"].upcase!
          if (aa["should_destroy"] == "false") && h[aa["name"]].nil?
            h[aa["name"]] = true
            new_authorships << aa
          end
        }
        story_params[:authorships_attributes] = new_authorships
      end

      # Try the update once more!
      logger.error "Caught duplicate taggings / authorships.  Will try again with new values: #{story_params.inspect}"
      @story.attributes = story_params.merge(last_edited_params)
    end

    # SSS: Weird!  When a story has no authorships, and this is the first time a source is added,
    # the authorships get lost on save, unless I inspect them.  What broke in the update to NT Baltimore?
    # This hack wasn't necessary earlier.
    @story.authorships.inspect

    # If the story is being submitted via a local site, automatically add the local site constraint tag!
    # But, not if it had already been listed previously!
    if ![Story::LIST, Story::FEATURE].include?(prev_story_status) && @local_site && !@story.taggings.map(&:tag_id).include?(@local_site.constraint.id)
      # SSS: NOTE: The story has not yet been saved to the database, so I have to use the in-memory taggings association rather
      # than use @story.tags which would fetch old info from the db!
      @story.taggings << Tagging.new(:tag_id => @local_site.constraint.id, :member_id => current_member.id) 
    end

    # Now, update story scope after taggings have settled down
    @story.set_story_scope(story_scope, @local_site)

      # 1. Try to list the story if it was previously in pending/queue status (the save will fail if any reqd. information is missing)
      # 2. Attribute submission to this member if the story was previously pending but is now list/feature
    @story.status = Story::LIST if [Story::PENDING, Story::QUEUE].include?(@story.status)
    @story.submitted_by_member = m if !was_public && @story.is_public?

    # Save and catch exceptions -- mysql errors.
    begin
      saved = @story.save
      error_message = "Failed to update story.<br/>#{@story.errors.full_messages.join('<br/>')}" if !saved
    rescue Exception => e
      logger.error "Exception #{e} saving story #{@story.id} with params #{params.inspect}"
      error_message = "Encountered an error saving story info. Please reload the toolbar and try again."
      saved = false
    end

    if saved
      update_errors = @story.update_errors
      @story.reload # To get latest values for 'edited_by_member'

      ActivityScore.boost_score(@story, :story_listed, {:member => m, :url_ref => params[:ref]}) if (!was_public && @story.is_public?)

        # New request: Send notifications only to staff
        # Send notifications to submitter (nothing to bots anymore!) if someone else edits their posted story
      if ![@story.edited_by_member,Member.nt_bot,Member.nt_anonymous].include?(submitter) && submitter.has_role_or_above?(:staff) && submitter.email_notification_preferences.story_edited 
        NotificationMailer.deliver_story_edited({:to_member => submitter, 
                                                 :body      => {:recipient   => submitter, 
                                                                :story       => @story, 
                                                                :submitter   => submitter,
                                                                :editor      => @story.edited_by_member}})
      end

        # New request: Send notifications only to staff
        # Send notifications to previous editor if someone else edits the story
        # But, if the previous editor & submitter were the same person, dont send it out again!
      if prev_editor && ![submitter,@story.edited_by_member,Member.nt_bot,Member.nt_anonymous].include?(prev_editor) && prev_editor.has_role_or_above?(:staff) && prev_editor.email_notification_preferences.story_edited
        NotificationMailer.deliver_story_edited({:to_member => prev_editor, 
                                                 :body      => {:recipient   => prev_editor, 
                                                                :story       => @story, 
                                                                :submitter   => submitter,
                                                                :editor      => @story.edited_by_member}}) 
      end

        # Send notifications to edits@... in all cases
      NotificationMailer.deliver_story_edited({:to_member_id => "#{SocialNewsConfig["email_addrs"]["edits"]}", 
                                               :body         => {:recipient   => nil, 
                                                                 :story       => @story, 
                                                                 :submitter   => submitter,
                                                                 :editor      => @story.edited_by_member}})

      respond_to do |format|
        format.html do
          if found_dupes
            flash[:notice] = dupe_error
          elsif update_errors.blank?
            flash[:notice] = 'Story was successfully updated.'
          else
            flash[:notice] = "Your edits have been saved, but we're still missing this story info:<br/><div class='edit_error'>#{update_errors.join('<br/>')}</div>Please re-edit the story to fill in this missing info.<br/>"
          end
          redirect_to @story
        end
        format.js do
          if found_dupes
            render :json => {:go => :edit_thanks, :notice => dupe_error, :delayed_form_reload => [:all], :reload_target => merged_story_path}.to_json
          elsif update_errors.blank?
            render :json => {:form_transition => {:from => :edit, :to => :edit_thanks}, :force_form_reload => true}.to_json
          else
            notice = "Your edits have been saved, but we're still missing this story info:<br/><div class='edit_error'>#{update_errors.join('<br/>')}</div><a href=\"#\" onclick=\"window.location=window.location.pathname+$.query.set('go','edit'); return false\">Click here</a> to fill in this missing info.<br/>"
            render :json => {:go => :edit_thanks, :notice => notice, :delayed_form_reload => [:info,:edit]}.to_json
          end
        end
      end
    else
      respond_to do |format|
        format.html {render :action => "edit", :layout => "popup"}
        format.js {render :json => {:error_message => error_message}.to_json}
      end
    end
  end

  def destroy
    @story = Story.find(params[:id])
    @story.destroy

    redirect_to stories_url
  end

  def destroy_image
    @story = Story.find(params[:id])
    respond_to do |format|
      if @story.image.destroy
        flash[:notice] = "Image Deleted" 
      else
        flash[:error] = "Image could not be deleted." 
      end
      format.html { redirect_to(edit_story_path(@story))}
    end
  end

  def destroy_video
    @story = Story.find(params[:id])
    respond_to do |format|
      if @story.video.destroy
        flash[:notice] = "Video Deleted" 
      else
        flash[:error] = "Video could not be deleted." 
      end
      format.html { redirect_to(edit_story_path(@story))}
    end
  end
  
  # This ajax action is most likely not necessary anymore, as the toolbar is the definitive
  # place to log clicks now.
  # POST /stories/:id/record_click
  #
  def record_click
    StoryClick.record_click(params[:id], session)
    respond_to { |format| format.js { render :json => "" } }
  end

  # POST /stories/:id/short_url
  def short_url
    #Story.update(params[:id], :short_url => params[:url].strip)
    ShortUrl.add_or_update_short_url(:page_type => 'Story', :page_id => params[:id], :local_site => @local_site, :short_url => params[:url].strip)
    respond_to { |format| format.js { render :json => "" } }
  end

  # POST /stories/:id/save
  # toggles existence of save
  def save
    story = Story.find(params[:id])
    starred = true
    m = current_member
    save = Save.find_by_member_id_and_story_id(m.id, params[:id])
    if save.nil?
      save = Save.new(:story_id => params[:id])
      m.saves << save
      m.save
      ActivityScore.boost_score(story, :like, {:member => m, :obj => save, :url_ref => params[:ref]})
    else
      ActivityScore.boost_score(story, :unlike, {:member => m, :obj => save})
      save.destroy
      starred = false
    end
    story.process_in_background
    respond_to do |format|
      format.html do
        flash[:notice] = (starred ? "You starred" : "You have unstarred") + " \"#{story.title}\""
        redirect_to member_url(m, :anchor => "picks")
      end
      format.js do
        render :json => "#{starred}"
      end
    end
  end
  
  # Fetch all the metadata we can find about this story by querying a number of APIs.
  # This can take a while, which is why we do it in a second step--as an ajax call from
  # the toolbar after loading.
  #
  def fetch_metadata
    @story = Story.find(params[:id])
    extra_info = StoryAutoPopulator.update_story_metadata_from_apis(@story)
    @story.bot_topics = extra_info[:topics] # SAP doesn't set this itself for some reason
    @story.save
    render :json => build_story_data_hash(@story, extra_info)
  end
  
  protected
    
    def access_denied
      store_location
      redirect_to new_member_url(use_popup_layout ? {:popup => "true"} : {})
    end
    
  private
    
    # Assemble the JSON hash for jquery.fetch_metadata.js; these fields get highlighted in yellow
    # in the Toolbar Edit Form. We might want the hash to only contain _changed_ fields, and not all,
    # but for now, this makes sense, as it represents the collective efforts of the SAP _and_ the MdF.
    #
    def build_story_data_hash(story, extra_info = {})
        # In situations where the story already exists in the db without a date (legacy data, buggy data from earlier, whatever), we get a null date
      sdate = story.story_date || Time.now

        # Base story data -- common to all stories (pending, list, existing, new ...) that go through this method
      story_data = {
        :title           => story.title,
        :story_type      => story.story_type,
        :date_components => {:month => sdate.month, :day => sdate.day, :year => sdate.year},
        :authors         => story.journalist_names,
        :quote           => story.excerpt
      }
      
      # As this is now called from the toolbar, story will never be new, right?
      # Even its authorships & taggings should be saved to the db by now...
      # TODO: wipe out commented-out cruft when we're sure it's not needed
      # 
      # if story.new_record?
      #   story_data[:authorships] = story.authorships.collect{|a| {:name => a.name}}
      #   story_data[:topics] = extra_info[:topics].collect{|t| {:name => t.name}} if (extra_info && extra_info[:topics])
      # else
          # Existing story -- so, pass along ids of existing association objects so that we don't get duplicates when we try to update the story!
        story_data[:authorships] = story.authorships.collect{|a| {:name => a.name, :id => a.id}}
        # SSS FIXME: Assumes national topics!
        story_data[:topics] = story.taggings.collect { |t| t.tag.tag_type.nil? ? nil : {:name => t.tag.name, :id => t.id} }.compact if story.taggings
      # end

      return story_data
    end

    def output_html
      @url_tracking_key = "ll"
      @has_story_listings = true
      @listing_title = get_listing_title(params)
      @title = @listing_title.clone
      @title.gsub!(/<span.*?>(.*?)<\/span>/) { |m| $1 }
        # RSS feeds not provided for listings with "&key=val" url parameters
      @rss_autodiscovery_links = [ { :link => request.request_uri + ".xml", :title => @title } ] if (request.request_uri !~ /\?/)
      @cached_fragment_name = get_cached_fragment_name(nil, "stories")
      @cached_story_ids     = get_cached_story_ids_and_when_fragment_expired(@cached_fragment_name, @@story_listings_refresh_time.seconds) do
        @topic   = Topic.find_topic(params[:t_slug], @local_site) if params[:t_slug]
        @subject = Subject.find_subject(params[:s_slug], @local_site) if params[:s_slug]
        @group   = Group.find_by_id_or_slug(params[:g_slug]) if params[:g_slug]
        # For recent reviews
        if (params[:with_notes_only])
          params[:listing_type_opts] = { :with_notes_only => params.delete(:with_notes_only) }
        end
        # Override as per Fab's request
        params[:per_page] ||= 20 if params[:listing_type] == "recent_reviews"
        @stories = Story.normalize_opts_and_list_stories_with_associations(@local_site, params.merge(:paginate=>true))
        @will_be_cached = true

          # Last statement in block should yield a flat list of story ids
        @stories.map(&:id)
      end
    end

    #
    def output_rss
      params[:per_page] = 25 # FIXME: Parameterize this
      tp = @local_site ? "#{@local_site.name} " : ""
      tp = params[:g_slug] ? "#{tp}: #{Group.find(params[:g_slug]).name}: " : tp
      @feed_data = {
        :feed_title  => tp + get_rss_feed_title(params.merge({:source => @source_name}), params[:s_slug] ? "subjects" : (params[:t_slug] ? "topics" : nil)),
        :listing_url => request.url.sub(/.xml$/, ''),
        :items       => Story.normalize_opts_and_list_stories(@local_site, params)
      }
      render :layout => false, :template => "rss_feeds/stories.rss.builder"
    end

    #
    def output_json
      params[:per_page] ||= SocialNewsConfig["widgets"]["stories_per_widget"]
      tp = params[:g_slug] ? "#{Group.find(params[:g_slug]).name}: " : ""
      widget_params = {
        :local_site    => @local_site ? @local_site.name.downcase : nil,
        :title_prefix  => tp,
        :listing_url   => request.url.sub(/.json$/, ''),
        :listing_type  => params[:listing_type],
        :listing_topic => params[:t_slug] ? Topic.find_topic(params[:t_slug], @local_site).name \
                                          : (params[:s_slug] ? Topic.get_subject_name_from_slug(params[:s_slug]) : ""),
        :timespan      => params[:timespan] || StoryListingHelpers.default_date_window_size(@local_site, params),
        :source_name   => (@source ? @source.name : ""),
        :story_type    => params[:story_type],
        :source_ownership => params[:source_ownership] 
      }
      widget = widgetize_listing(widget_params, Story.normalize_opts_and_list_stories(@local_site, params))
      @metadata = widget[:metadata]
      @stories  = widget[:stories]
      render :layout => false, :template => "widgets/widgets.json.erb"
    end
    
    # This may be deprecated by the toolbar.
    #
    def use_popup_layout
      @@popup_actions.include?(action_name)
    end

    def merged_story_params
      m = current_member
      attrs = {
          # For stories submitted by new members, set low validation level! If guest submission, set to 1
        :editorial_priority  => (m ? (m.validation_level < SocialNewsConfig["min_trusted_member_validation_level"].to_i ? m.validation_level : 3) : 1),
        :submitted_by_member => (m ? m : Member.nt_anonymous),
        :content_type        => params[:content_type] || "article",
        :status              => params[:status] || Story::PENDING,
        :url                 => params[:url],
        :title               => params[:title],
        :referred_by         => params[:ref],
        :story_date          => params[:story_date],
        :excerpt             => params[:story_quote] || "",
        :journalist_names    => params[:journalist_names] || "",
        :story_type          => params[:story_type]
      }

        # If we have params passed in through params[:story], merge that in!
        # But convert all strings to symbols!
      ps = params[:story] || {}
      ps.keys.each { |k| attrs[k.to_sym] = ps[k] }

      # Cleanup params before returning it
      if attrs[:story_type]
        attrs[:story_type].downcase!
        attrs[:story_type].gsub!(" ", "_")
      end

      attrs
    end
    
    # To be used when new'ing reviews
    #
    def default_review_params
      {:form_version => "review:mini"}
    end

    def member_has_posting_quota?(m)
      if m.has_role_or_above?(:editor)
        true
      else
        n = ActivityEntry.count(:conditions => ["member_id = ? AND activity_type = ? AND created_at >= ?", m.id, 'Story',  Time.now.beginning_of_day])
        n < SocialNewsConfig["max_posts_per_day"].to_i
      end
    end
end
