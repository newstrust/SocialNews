class ReviewsController < ApplicationController
  include FacebookConnectHelper
  include TwitterHelper

  before_filter :login_required, :except => [:new, :index, :show, :overall_rating, :recent]
  
  @@popup_actions = ["new", "edit", "update", "create"]
  cattr_reader :popup_actions

  def index
  end

  def show
    @review = Review.find(params[:id])
    render_403(Review) and return unless @review.is_public? or (logged_in? and (current_member.has_role_or_above?(:editor) or (current_member == @review.member)))
    @meta_review = @review.meta_review_by_member(current_member) if current_member
    @related_stories = StoryRelation.find(:all,
      :conditions => {:story_id => @review.story_id, :member_id => @review.member_id}
      ).map(&:related_story)
    @related_stories.reject!{|s| s.nil? || s.status == 'hide'} unless logged_in? and current_member.has_role_or_above?(:editor)
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  # Legacy Review Form. DEPRECATED, redirect to toolbar!
  #
  def new
    story = Story.find(params[:story_id])
    redirect_to(toolbar_story_path(story, {:popup => true}))
  end
  
  # Legacy Edit Review Form. DEPRECATED, redirect to toolbar!
  #
  def edit
    new
  end

  # As of the Toolbar launch, this is now an ajax call.
  def create
    @m = current_member
    @review = Review.new(review_params(params).merge(:member => @m, :status => (@m.is_public? ? "list" : "hide")))
    @review.local_site = @local_site
    @review.referrer_code = params[:ref]
    story = @review.story

    # SSS: Weird bug?  What is going on?  Excerpts are lost if they aren't inspected and hence materialized?
    # Am I doing something wrong with setting these up?
    @review.excerpts.inspect

      # Update story information since the story could be reviewed from the todays feeds page where the
      # story status is not yet list, and the submitter is still bot!
    params[:story][:status] = Story::LIST if (story.status == Story::QUEUE) || (story.status == Story::PENDING)
    params[:story][:submitted_by_id] = @m.id if (story.submitted_by_id == Member.nt_bot.id)

    update_story_attributes(@review, params[:story]); story.reload # reload story after save
    update_member_settings(@review, params[:review_form_expanded])
    update_source_review(story, params[:source_ratings])

    begin
      saved = @review.save_and_process_with_propagation
    rescue ActiveRecord::StatementInvalid => e
      # Likely double submits that got through any front-end protections we have!
      logger.error "Exception #{e} trying to save review for #{story.id} by member #{@m.id}.  Recovering!"

      # Fetch saved review -- turn off tweet (to prevent a duplicate tweet!)
      @review = Review.find_by_story_id_and_member_id(story.id, @m.id)
      if @review
        saved = true
        if params[:post_on_twitter] == "1"
          params[:post_on_twitter] = nil
          notice = "Your review might have been tweeted.  Because of an unexpected error, we cannot confirm this.  Please check your twitter stream."
        end
        params[:post_on_facebook] = nil
      else
        saved = false
      end
    end

    if saved
      notice = tweet_if_requested(@review, params[:short_url])
      with_message = @m.status == "guest" ? :guest : !@m.is_public? ? :suspended : nil
      render :json => { :go                  => :story_actions,
                        :form_transition     => {:from => :review, :to => :story_actions},
                        :delayed_form_reload => [:review],  # No need to forcibly reload the entire toolbar right away!
                        :notice              => notice,
                        :fb_stream_story     => toolbar_facebook_stream_story(@review),
                        :with_message        => with_message }.to_json
    else
      # If we get an error in saving the review, it is likely because of double submits that got through any front-end checks we have!
      render :json => {:error_message => "Failed to save review.  Please try again."}.to_json
    end
  end

  # As of the Toolbar launch, this is now an ajax call.
  #
  def update
    @review = Review.find(params[:id])
    @review.attributes = review_params(params)

    update_story_attributes(@review, params[:story])
    update_member_settings(@review, params[:review_form_expanded])
    update_source_review(@review.story, params[:source_ratings])
    
    if @review.save_and_process_with_propagation
      if current_member.status == 'guest'
        flash[:notice] = render_to_string(:inline => "<h2>Your review was successfully updated,<br>but will not be published until you activate your account.</h2>Check your email inbox and click on your activation link. For help, check our <%= help_link('FAQ', 'activate') %>.")
        render :json => { :go => :story_actions, 
                          :form_transition => {:from => :review, :to => :story_actions} }.to_json
      else
        notice = tweet_if_requested(@review, params[:short_url])
        render :json => { :go              => :story_actions, 
                          :form_transition => {:from => :review, :to => :story_actions}, 
                          :notice          => notice,
                          :fb_stream_story => toolbar_facebook_stream_story(@review) }.to_json
      end

      if @review.hidden? && !current_member.has_role_or_above?(:admin)
        NotificationMailer.deliver_edit_alert(:subject => "Hidden Review Updated", :body => "Check #{review_url(@review)}.")
      end
    else
      render :json => {:error_message => "Failed to save review"}.to_json
    end
  end
  
  def destroy
    @review = Review.find(params[:id])
    Story.find(@review.story_id).process_in_background # Re-process the reviewed story
    @review.destroy

    redirect_to reviews_url
  end
  
  def meta_review
    review = Review.find(params[:meta_review][:review_id])
    meta_review = review.meta_review_by_member(current_member)
    meta_review.attributes = params[:meta_review]
    meta_review.save_and_process_with_propagation
    render :json => "\"OK\""
  end

  # ajax call for review form
  # set up temp fake-o review object, run it though Ratings::process, ideally w/o hitting the db at all
  def overall_rating
    overall_rating = 0.0
    rparams = params[:review]
    if rparams # sometimes ajax calls come in before dom is ready, it seems
      rparams = review_params(params).reject{|key,val| ["excerpts_attributes"].include?(key)}
      # For mini-reviews, since we don't display the trust question, we cannot use
      # the source rating value in computing the overall rating!
      if rparams[:form_version] =~ /mini/ && params[:source_ratings]
        rparams[:source_review] = SourceReview.new(:rating_attributes => params[:source_ratings]) 
      end
      temp_review = Review.new(rparams)
      new_processed_ratings = Ratings::process(temp_review, true, nil)
      overall_rating = new_processed_ratings[0]['overall'] || 0.0
    end
    render :inline => {:rating => ("%.1f" % overall_rating), :percent => ((overall_rating.to_f / 5) * 100).to_i}.to_json
  end

  def recent
    conditions  = "reviews.member_id IS NOT NULL AND reviews.status IN ('list', 'feature')"
    conditions += " AND reviews.comment != ''" if params[:with_notes]
    @reviews = Review.paginate(:page => params[:page] || 1,
                               :per_page => 25,
                               :joins => "JOIN stories ON reviews.story_id=stories.id AND stories.status in ('#{Story::LIST}', '#{Story::FEATURE}')",
                               :conditions => conditions,
                               :order => "reviews.created_at DESC")
  end

  protected
    
    def access_denied
      store_location
      redirect_to new_member_url(use_popup_layout ? {:popup => "true"} : {})
    end
    
  private

    # Get the facebook feed story to publish via the toolbar.
    def toolbar_facebook_stream_story(review)
      if (params[:post_on_facebook] == "1") && publishable_via_fb_connect
        FbConnectPublisher.stream_story_for_review(review, :home_url => home_url, :story_url => story_url(review.story), :review_url => review_url(review.story, review), :toolbar_url => toolbar_story_url(review.story))

      end
    end

    def tweet_if_requested(review, short_url)
      if (params[:post_on_twitter] == "1")
        story = review.story
        # In case the tweet doesn't have the tweetable url already (because of network failure, timeout, whatever), add it in
        tweet, short_url = update_tweet_with_short_url(params[:tweet], sharable_story_url(story, :ref => "tw"), short_url)
        resp = tweet_it(current_member, tweet)
        if story.short_url.blank?
          ShortUrl.add_or_update_short_url(:page => story, :local_site => @local_site, :url_type => ShortUrl::TOOLBAR, :short_url => short_url)
        end
        current_member.record_published_review(@review.id, Sharable::TWITTER) if resp[:error].blank?
        resp[:notice] || resp[:error]
      end
    end

    # for story_relations...
    def update_story_attributes(review, story_params)
      review.story.update_attributes(story_params)
    rescue Exception => e
      logger.error "Exception #{e} saving story attributes for #{review.id}; Backtrace: #{e.backtrace * '\n'}"
    end

    def update_member_settings(review, review_form_expanded)
      current_member.update_attributes(:preferred_review_form_version => review.form_version, :review_form_expanded => review_form_expanded)
    end

    # each time a member fills out a review they may also be editing a secret 'source review'...
    # we're basically maintaining two types of reviews in one controller
    def update_source_review(story, ratings_attributes, member=current_member, propagate=true)
      # Can be nil if story info is incomplete -- with introduction of the toolbar, this is definitely possible!
      # Someone might review a story without filling out all reqd. info!
      return if story.primary_source.nil?

      source_review = story.primary_source.source_review_by_member(@local_site, member)
      old_rating = source_review.rating
      new_rating = ratings_attributes["trust"]["value"].to_i

      # Nothing to do if there is no existing source review and there is no rating now, OR if the rating itself hasn't changed
      return if (source_review.new_record? && (new_rating == 0)) || (new_rating == old_rating)

      source_review.rating_attributes = ratings_attributes
      propagate ? source_review.save_and_process_with_propagation : source_review.save
    end

    def use_popup_layout
      @@popup_actions.include?(action_name)
    end
 
    def review_params(params)
      # Do not include source trust in the rating computation for mini review forms
      # FIXME: But, this is a bit weird.  All previously answered questions (even those hidden from the form)
      # are used in rating computation.  Ideally, they shouldn't be.
      params[:review][:rating_attributes].merge!(params[:source_ratings]) unless params[:review][:form_version] =~ /mini/
      return params[:review]

  # SSS: Note:
  # Right now, the label input values aren't required -- the labels can just be a front-end
  # UI thing, and all labels can be converted to rating inputs as before.  But, if in the future, 
  # we want to diverge the rating & labelling forms, at that time, we will need these labels stored
  # in the db in some form.  In anticipation, I am retaining code that processes labels,
  # but commenting it out
  #
  #    rps = params[:review]
  #    label_attrs = rps.delete("label_attributes")
  #    if params[:form_version] =~ /label/
  #      rps[:rating_attributes] ||= {}
  #      rps[:rating_attributes].merge!(Rating.labels_to_ratings(label_attrs))
  #      params[:source_ratings] = {:trust => rps[:rating_attributes].delete(:trust)} unless no_src_attrs
  #    else
  #      rps[:rating_attributes].merge!(params[:source_ratings]) unless rps[:form_version] =~ /mini/
  #    end
  #    return rps
    end
end
