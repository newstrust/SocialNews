class MembersController < ApplicationController
  include OpenidProfilesHelper
  include PartnersHelper
  include StoriesHelper
  include SessionsHelper
  include FacebookConnectHelper
  include TwitterHelper
  include MynewsHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  before_filter :bots_not_allowed, :except => [:index, :show]
  before_filter :login_required, :only => [:my_account, :me, :update, :inviting, :invite, :manage_subscriptions, :manage_subscription, :welcome, :publish_reviews_and_posts]
  before_filter :find_member_through_activation_code, :only => [:activate, :accept_invitation, :accepting_invitation]
  before_filter { |controller| controller.send(:use_partner_layout) if controller.params['partner_id'] }
  before_filter :find_member_and_verify_profile_access, :only => [:show, :comments, :reviews, :picks, :submissions, :meta_reviews_given, :meta_reviews_received]

    # Conditionally cache JSON & XML listing requests
    # Caution! It might seem that !c.request.format.html? should work ... but, if we get in an invalid format, that check will succeed!
  caches_page :reviews, :reviews_with_notes, :picks, :submissions, :if => Proc.new { |c| c.request.format.js? || c.request.format.json? || c.request.format.xml? || c.request.format.rss? }

  def index
    @featured_members = Member.find_featured(@local_site)
    # how_many, with_photo, is_logged_in, home_page_name_list, local_site
    @recent_reviewers_photo = Member.find_recent_reviewers(24, :with_photo => true, :is_logged_in => logged_in?, :local_site => @local_site)
    @recent_reviewers = Member.find_recent_reviewers(40, :is_logged_in => logged_in?, :local_site => @local_site)
  end

  def trusted
    @trusted_members = Member.find_trusted
    respond_to do |format|
      format.html do render :layout => (params[:popup] ? "popup" : nil) end
    end
  end

  def mynetwork
    @member = params[:id] ? Member.find(params[:id]) : current_member
    render_404 and return if @member.nil?

    unless logged_in? || is_public_mynews?(@member)  # skip this if a public page, or not logged in
      store_location
      flash[:notice] = "Please Log In first to access this network page."
      redirect_to new_sessions_path and return 
    end

    @my_page = logged_in? && current_member == @member

    unless @my_page || is_visible_mynews?(@member)
      render_403(Member) and return
    end

    setup_followers_activity
    setup_followed_members_activity
    setup_network_activity
    @has_story_listings = true
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def network_activity_ajax_listing
    @member = Member.find(params[:id])
    @my_page = logged_in? && current_member == @member
    @followed_members = params[:member_id] ? [Member.find(params[:member_id])] : @member.followed_members
    setup_network_activity
    render :partial => "network_activity", :locals => {:activities => @network_activity_entries, :activity_hash => @network_activity_hash, :my_page => @my_page, :followed_members => @followed_members }
  end

  def followers_activity_ajax_listing
    @member = Member.find(params[:id])
    @my_page = logged_in? && current_member == @member
    setup_followers_activity
    render :partial => "followers_activity"
  end

  def followed_members_activity_ajax_listing
    @member = Member.find(params[:id])
    @my_page = logged_in? && current_member == @member
    setup_followed_members_activity
    render :partial => "followed_members_activity"
  end

  # GET /members/search
  def search
      # Search by name -- not by all fields
    @results = empty_query? ? [] : Member.search(:conditions => {:name =>  params[:q]})
    respond_to do |format|
      format.js do
          ## Only show public members!
        members = @results.reject { |x| !x.is_public?}.compact
        cm = current_member
        if params[:mynews]
          output = members.map {|x| "#{x.name}|#{x.id}|#{x.favicon}|#{member_path(x)}|#{fbc_session_user_friends_with?(x) ? 'true' : 'false'}|#{is_twitter_follower?(cm, x) ? 'true' : 'false'}|#{cm && cm.mutual_follower?(x)}" }
        else
          output = members.map {|x| "#{x.name}|#{x.friendly_id}" }
        end
        render :json => output.compact.join("\n").to_json
      end
    end
  end

  def login_available
    params[:id] = params[:q] if params[:q] # Autocomplete plugin uses q as a param but we want id
    params[:id].strip! if params[:id]
    @exists = Member.find_by_name(params[:id])  unless empty_query?
    respond_to do |format|
      format.js do
        render :inline => @exists ? '1' : '0'
      end
    end
  end
  
  def last_active_at
    m = current_member
    if m.nil?
      access_denied
    else
      m.bypass_save_callbacks = true
      m.update_attribute(:last_active_at, Time.now)
      respond_to do |format|
        format.js { render :inline => '', :status => '200' }
      end
    end
  end

  def record_fb_stream_post
    case params[:post_type]
      when "review"
        r = Review.find(params[:review_id])
        if !r.nil?
          r.member.record_published_review(r.id, Sharable::FACEBOOK)
          respond_to { |format| format.js { render :inline => '', :status => '200' } }
        else
          respond_to { |format| format.js { render :inline => "Unknown review id #{params[:review_id]}", :status => '200' } }
        end
      else
        respond_to { |format| format.js { render :inline => "Unknown post type #{params[:post_type]}", :status => '200' } }
    end
  end

  def show
    # If this visitor cannot see the member's full profile, no point loading a ton of stuff from the db
    render :action => :show && return if !@member.full_profile_visible_to_visitor?(current_member)

    if @member.has_public_profile?
      @rss_autodiscovery_links = [ {:link => "/members/#{@member.id}/reviews.xml", :title => "#{APP_NAME}: #{@member.name}'s Reviews"},
                                   {:link => "/members/#{@member.id}/picks.xml", :title => "#{APP_NAME}: #{@member.name}'s Picks"},
                                   {:link => "/members/#{@member.id}/submissions.xml", :title => "#{APP_NAME}: #{@member.name}'s Posts"}]
    end

    @url_tracking_key = "mp"
    @has_story_listings = true

# SSS: New code based on use of activity entries
#
#    @activity_entries = activity_entries.paginate(:all, pagination_params(:per_page => 50, :order => "updated_at DESC"))
#
#    @starred     = Save.find_all_by_id(@activity_entries.reject    { |ae| ae.activity_type != 'Save'}.map(&:activity_id), :include => :story)
#    @reviews     = Review.find_all_by_id(@activity_entries.reject  { |ae| ae.activity_type != 'Review'}.map(&:activity_id), :include => :story)
#    @comments    = Comment.find_all_by_id(@activity_entries.reject { |ae| ae.activity_type != 'Comment'}.map(&:activity_id))
#    @submissions = Story.find_all_by_id(@activity_entries.reject   { |ae| ae.activity_type != 'Story'}.map(&:activity_id))
#
#    @all_starred_count = Save.count(:conditions => {:member_id => @member.id})

    # Pay attention.  We need a total of 40 activity entries -- but, we want to pick the most recent 40, independent
    # of whether it is a post, review, or like.  So, pick 40 each of each type, combine them, order them by time
    # and pick the top 40 (and thus rejecting the other 80)

    # not using get_picks; we need the save object to do our "poor man's news feed" in chronological order
    @starred = Save.find_all_by_member_id(@member.id,
      :include => :story,
      :conditions => member_is_owner_or_has_role?(:editor) ? "" : Story.is_public_sql_clause,
      :limit => 40,
      :order => "saves.created_at DESC")
    @all_starred_count = Save.count(:conditions => {:member_id => @member.id})
    @submissions = get_submissions(40)
    @reviews = get_reviews(40)

      # For editors, show all comments (hidden or not) for this member
      # For non-editors / guests, show visible comments only if the member has commenting privileges
    if (current_member && (current_member.has_role_or_above?(:editor)))
      @comments = @member.comments.paginate(:all, pagination_params(:per_page => 40, :order => "created_at #{(params[:filter_by] == "oldest" ? "ASC" : "DESC")}")).reject { |c| c.commentable_type.nil? }
    elsif @member.can_comment?
      @comments = @member.comments.visible.paginate(:all, pagination_params(:per_page => 40, :order => "created_at #{(params[:filter_by] == "oldest" ? "ASC" : "DESC")}")).reject { |c| c.commentable_type.nil? || (c.commentable.respond_to?(:status) && c.commentable.status == Status::HIDE)  }
    else
      @comments = []
    end

      # Do our "poor man's news feed": mash all the data up and sort uniformly by most recently updated first
      # For reviews, ordering is based on updated time, for stories & starred items, it is based on created time
      # Sort the (upto 120) entries and pick the top 40
    @activity_entries = (@starred + @submissions + @reviews + @comments).sort{ |x,y|
                             t_x = x.class == Review ? x.updated_at : x.created_at
                             t_y = y.class == Review ? y.updated_at : y.created_at
                             (t_x.nil? ? -1 : (t_y.nil? ? 1 : t_y <=> t_x)) # Buggy data (legacy info?) without dates!
                        }[0..39]

       # 1. Throw away all entries that aren't in the final merged list
    @reviews.reject!     { |r| !@activity_entries.include?(r) }
    @starred.reject!     { |l| !@activity_entries.include?(l) }
    @submissions.reject! { |s| !@activity_entries.include?(s) }
    @comments.reject!    { |c| !@activity_entries.include?(c) }

       # 2. Set story flags for each story based on whether it's been reviewed / liked / posted
       #    But, UGH! Hack! Pass along the review object in story flags!
    @story_flags = {}
    @reviews.each     { |r| sid = r.story.id; @story_flags[sid] ||= {}; @story_flags[sid][:reviewed] = r }
    @starred.each     { |l| sid = l.story.id; @story_flags[sid] ||= {}; @story_flags[sid][:starred] = true }
    @submissions.each { |s| sid = s.id;       @story_flags[sid] ||= {}; @story_flags[sid][:posted] = true }

    @current_member_rating = @member.average_rating_by_member(current_member)

      # Pick 5 meta-reviews (given, received) for the right hand column
    @num_meta_reviews_to_show = 3
    @meta_reviews_given    = MetaReview.paginate_given_by_member(@member, :per_page => @num_meta_reviews_to_show)
    @meta_reviews_received = MetaReview.paginate_received_by_member(@member, :per_page => @num_meta_reviews_to_show)
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def comments
    @comments = case params[:filter_by]
    when 'oldest'
      @member.comments.paginate(pagination_params(:order => 'created_at ASC')).reject { |c| c.commentable_type.nil? }
    else
      @member.comments.paginate(pagination_params(:order => 'created_at DESC')).reject { |c| c.commentable_type.nil? }
    end
  end

  # render new.rhtml
  def new
    store_referer_location
    if logged_in?
      flash[:notice] = "You are logged into an existing #{APP_NAME} account. Please logout if you wish to create a new account."
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, home_url)
    else
      @member = Member.new
      render :layout => "popup" if params[:popup]
    end
  end
  
  def my_account
    @member = current_member
    render :action => 'edit'
  end
  
  # evil admin-only method to edit people who aren't you
  def edit_account
    redirect_to access_denied_url and return unless logged_in? and current_member.has_role_or_above?(:admin)
    @member = Member.find(params[:id])
    render :action => 'edit'
  end

  def publish_reviews_and_posts
    redirect_to access_denied_url and return unless logged_in? and current_member.has_role_or_above?(:admin)
    @member = Member.find(params[:id])
    @member.publish_reviews_and_posts
    flash[:notice] = "All of #{@member.name}'s posts and reviews have been published!"
    redirect_to member_path(@member)
  end
  
  def me
    params[:id] = current_member.id
    show
    render :action => 'show'
  end
  
  def default_invite
    @invite = @partner.primary_invite
    redirect_to new_member_path(:partner_id => @partner.to_param, :invitation_id => @partner.primary_invite.id)
  end
  
  # Used by partners to sign up members
  def display_invitation
    @member = Member.new
    if @invitation && (!@invitation.welcome_page_template.blank? || !@invitation.welcome_page_link.blank?)
      redirect_to @invitation.welcome_page_link unless @invitation.welcome_page_link.blank?
      # Otherwise just render this page using the template.
    else
      
      # No invitation found so use Plan B
      redirect_to new_member_path(:partner_id => @partner.to_param, :invitation_id => @invitation.to_param)
    end
  end
 
  # temporary solution: eventually editors should be able to select which invitation is displayed by default
  def display_latest_invitation
    redirect_to(:action => :display_invitation, :partner_id => @partner.to_param, :invitation_id => @partner.primary_invite.id)
  rescue
    logger.info "No partner found for url #{request.url}!  Rendering 404"
    render_404
  end
  
  # Used by members to refer their friends.
  def invite
    @member = Member.new
  end
  
  # these methods are for accepting PERSONAL invites (from invite above), not partner ones
  def accept_invitation
  end
  
  def accepting_invitation 
    if verify_recaptcha(@member) && @member.update_attributes(params[:member])
      activate and return false
    else
      render :action => 'accept_invitation'
    end
  rescue ActiveRecord::StatementInvalid => e
    flash[:error] = "Member name already taken" if e.message =~ /Mysql::Error: Duplicate entry/ || e.message =~ /index_members_on_name/
    render :action => 'accept_invitation'
  end
  
  # only allow edits to current_member
  def update
    @member = Member.find(params[:id])
    redirect_to access_denied_url and return unless member_is_owner_or_has_role?(:admin)
    
    # We need to flip this attribute around to do the opposite of how it's set.
    # this is because it makes more sense to say something like "comments enabled" 
    # than "comments not enabled" in the view.
    @member.muzzled = params[:member][:not_muzzled] == "0" ? "1" : "0"
    params[:member].delete(:not_muzzled)
    # SSS FIXME: Maybe rename :newsletter to :newsletter_subscription_attrs to avoid this fixup?
    params[:member][:newsletter_subscription_attrs] = params[:member].delete(:newsletter)

    @member.attributes = last_edited_params # do this first, in case validation_level is updated
    @member.attributes = params[:member].merge(:flex_attributes_params => params[:member_attributes])
    @member.image = Image.new(params[:image]) if params[:image] && !params[:image][:uploaded_data].blank?

    # Enforce student constraints
    @member.enforce_student_constraints!
    
    if @member.save_and_process_with_propagation # recalc member level, too!
      if current_member == @member
        flash[:notice] = 'Your account settings were successfully updated.'
      else
        flash[:notice] = @member.display_name + "'s account settings were successfully updated."
      end
      redirect_to @member
    else
      render :action => "edit"
    end
  rescue ActiveRecord::StatementInvalid => e
    flash[:error] = "Member name already taken" if e.message =~ /Mysql::Error: Duplicate entry/ || e.message =~ /index_members_on_name/
    render :action => "edit"
  end
  
  def inviting
    raise ArgumentError unless params[:member] && params[:member][:email]
    @invited_by = current_member
    @member = Member.create_through_member_referral(@invited_by, params[:member][:email])
    flash[:notice] = "Invitation Sent!"
    redirect_to invite_members_path
  rescue ArgumentError
    flash[:error] = "A valid email is required"
    redirect_to invite_members_path
  rescue ActiveRecord::StatementInvalid
    flash[:error] = "This person was already invited!"
    redirect_to invite_members_path
  end

  def normal_create
    cookies.delete :auth_token
    # SSS FIXME: Maybe rename :newsletter to :newsletter_subscription_attrs to avoid this fixup?
    params[:member][:newsletter_subscription_attrs] = params[:member].delete(:newsletter)
    @member = Member.new(params[:member])
    @member.record_request_env(request.env)
    @member.accept_invitation(@invitation) if @invitation
    if [@member.valid?, verify_recaptcha(@member)].all? && @member.save!
      @partner.members << @member if @partner
      @invitation.group.process_join_request(@member) if @invitation && @invitation.group
      @local_site.process_signup(@member) if @local_site
      self.current_member = @member
      flash[:notice] = "Thanks for signing up! To activate your account, check your email."
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, "/start")
    else
      if @member.errors.on(:email)
        @existing_member = Member.find_by_email(@member.email)
        if @existing_member.has_invite?
          flash[:notice] = "This address was sent an invite, we've resent it to you."
          Mailer.deliver_signup_invitation_notification(@existing_member)
          redirect_to new_member_path and return false
        else
          unless @existing_member.active?
            flash[:notice] = "You already signed up, you just need to activate your account. We resent your activation email."
            Mailer.deliver_signup_notification(@existing_member)
            redirect_to new_member_path and return false
          end
        end if @existing_member
      end
      render({:action => 'new'}.merge(params[:popup] ? {:layout => "popup"} : {}))
    end
  rescue ActiveRecord::RecordInvalid
    render({:action => 'new'}.merge(params[:popup] ? {:layout => "popup"} : {}))
  rescue Exception => e
    logger.error "DEBUG: Exception #{e} creating new member account! #{params[:member].inspect}; Backtrace: #{e.backtrace * '\n'}"
    flash[:error] = "We are sorry. We encountered an unexpected error creating your account and have logged details about it. Please pick a different name / email and try again. If that doesn't work, please email us at #{SocialNewsConfig["email_addrs"]["feedback"]} and we'll investigate. Sorry about the inconvenience!"
    render({:action => 'new'}.merge(params[:popup] ? {:layout => "popup"} : {}))
  end

  def activate
    if logged_in? && !current_member.active?
      current_member.activate
      flash[:notice] = "<h2>Sign up complete!</h2>Please fill in your profile, to increase your member level."
      redirect_to '/members/my_account#profile' and return false
    else
      redirect_back_or_default(new_sessions_path)
    end
  end

  def manage_subscription
    freq = params[:freq]
    @member = current_member
    if params[:member]
      ## Update
      begin
        if (freq == Newsletter::BULK)
          @member.bulk_email = params[:member][:bulk_email]
        else
          @member.update_newsletter_subscription(freq, params[:member][:newsletter] && params[:member][:newsletter][freq] ? true : false)
        end
        @member.newsletter_format = params[:member][:newsletter_format]
        @member.save!
        flash[:notice] = "Your settings have been saved!"
      rescue Exception => e
        flash[:error] = "We encountered an error trying to update your settings! Please try again!"
        logger.error "Exception: #{e}; Backtrace: #{e.backtrace * '\n'}"
      end
      flash.discard
    end
    render :template => "members/manage_#{freq}"
  end

  def manage_subscriptions
    @member = current_member

    if params[:member]
      ## Update
      begin
        @member.newsletter_subscription_attrs = params[:member][:newsletter]
        @member.bulk_email         = params[:member][:bulk_email]
        @member.newsletter_format  = params[:member][:newsletter_format]
        @member.save!
        flash[:notice] = "Your settings have been saved!"
      rescue Exception => e
        flash[:error] = "We encountered an error trying to update your settings! Please try again!"
        logger.error "Exception: #{e}; Backtrace: #{e.backtrace * '\n'}"
      end
      flash.discard
    end
  end

  # /newsletter/:freq/unsubscribe/UNSUBSCRIBE-KEY-HERE
  def unsubscribe_from_newsletter
    begin
      key = params[:key]
      @m = Member.get_unsubscribing_member(key)

        ## Green signal!  Unsubscribe!
      @freq = params[:freq]
      if (@freq == Newsletter::BULK)
        @m.bulk_email = false
      else
        @m.remove_newsletter_subscription(@freq)
      end
      @m.save
    rescue Exception => e
      if current_member.nil?
        flash[:error] = "We are sorry! We had a problem processing your unsubscribe request.<br />Please Log In to change your newsletter delivery settings on your 'My Account' page."
        redirect_to :controller => "/sessions", :action => "new" and return
      else
        link_str = render_to_string(:inline => "<%= link_to 'My Account', '/members/my_account/#emails' %>")
        flash[:error] = "We are sorry! We had a problem processing your unsubscribe request.<br />Please update your newsletter delivery settings on your #{link_str} page."
        redirect_to member_url(current_member) and return
      end
    end
  end
  
  def reviews
    with_notes = (params[:review_type] == 'reviews_with_notes')
    respond_to do |format|
      format.html {
        @reviews = get_reviews(50, with_notes); @sub_heading = "(those with a note)" if with_notes
        @rss_autodiscovery_links = [ {:link => "/members/#{@member.id}/reviews.xml", :title => "#{APP_NAME}: #{@member.name}'s Reviews"} ] if @member.has_public_profile?
      }
      format.json { output_widget(get_reviews(10, with_notes, true).collect { |r| s = r.story; s.member_review = r; s }, !with_notes, true, "Reviews") }
      format.js   { output_widget(get_reviews(10, with_notes, true).collect { |r| s = r.story; s.member_review = r; s }, !with_notes, true, "Reviews") }
      format.rss  { output_rss("Reviews", get_reviews(25, with_notes, true), "rss_feeds/reviews.rss.builder") }
      format.xml  { output_rss("Reviews", get_reviews(25, with_notes, true), "rss_feeds/reviews.rss.builder") }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No Member Found."
    redirect_to home_url
  end

  def picks
    respond_to do |format|
      format.html { 
        @saved_stories = get_picks(50) 
        @rss_autodiscovery_links = [ {:link => "/members/#{@member.id}/picks.xml", :title => "#{APP_NAME}: #{@member.name}'s Picks"} ] if @member.has_public_profile?
      }
      format.json { output_widget(get_picks(10, true), true, false, "Picks") }
      format.js   { output_widget(get_picks(10, true), true, false, "Picks") }
      format.rss  { output_rss("Picks", get_picks(25, true), "rss_feeds/stories.rss.builder") }
      format.xml  { output_rss("Picks", get_picks(25, true), "rss_feeds/stories.rss.builder") }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No Member Found."
    redirect_to home_url
  end

  def submissions
    respond_to do |format|
      format.html { 
        @submissions = get_submissions(50)
        @rss_autodiscovery_links = [ {:link => "/members/#{@member.id}/submissions.xml", :title => "#{APP_NAME}: #{@member.name}'s Posts"} ] if @member.has_public_profile?
      }
      format.json { output_widget(get_submissions(10, true), true, false, "Story Posts") }
      format.js   { output_widget(get_submissions(10, true), true, false, "Story Posts") }
      format.rss  { output_rss("Story Posts", get_submissions(25, true), "rss_feeds/stories.rss.builder") }
      format.xml  { output_rss("Story Posts", get_submissions(25, true), "rss_feeds/stories.rss.builder") }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No Member Found."
    redirect_to home_url
  end

  def meta_reviews_given
    @meta_reviews = MetaReview.paginate_given_by_member(@member, :per_page => 50, :page => params[:page])
    @given = true
    render :action => 'members/meta_reviews'
  end
  
  def meta_reviews_received
    @meta_reviews = MetaReview.paginate_received_by_member(@member, :per_page => 50, :page => params[:page])
    @given = false
    render :action => 'members/meta_reviews'
  end
  
  def destroy_image
    @member = Member.find(params[:id])
    if @member.image && @member.image.destroy
      flash[:notice] = "Profile photo deleted"
    else
      flash[:error] = "Profile photo could not be deleted"
    end
    redirect_to my_account_members_url
  end

  def process_dupe_reviews
    @dupes = session[:dupe_reviews]
  end

  def update_dupe_reviews
    m = current_member
    h = {}
    session[:dupe_reviews].each { |d| h[d[0].story.id] = d }
    params[:keep].each { |story_id, keep_review_id|
      s_dupes = h[story_id.to_i]
      s_dupes.each { |r|
        if (r.id == keep_review_id.to_i)
          r.member_id = m.id
          r.status = Review::LIST
          r.save_and_process_with_propagation
        else
          r.destroy
        end
      }
    }

      # Pick first story in the list -- we'll redirect user to this story page after processing
      # Good enough since unlikely to have more than 1 story with dupe reviews.
    s = session[:dupe_reviews].first[0].story
    session[:dupe_reviews] = nil

    flash[:notice] = "Updated your reviews successfully!"
    redirect_to story_url(s)
  end

  def tweet
    resp = tweet_it(current_member, params[:tweet])
    respond_to do |format|
      format.html { render :inline => resp[:notice] || resp[:error] }
      format.js { render :json => resp.to_json }
    end
  end

  include Admin::VisualizationsHelper

  def stats_dashboard
    @member = Member.find(params[:id])

      # Plot opts
    opts = { :normalize => false, :y_aggregate => false, :x_aggregate => false, :x_aggregate_reverse => false }

      # Reviews Rating Distribution
    query_string = "select format(review_summary.rating, 1), count(*) from review_summary, stories where review_summary.member_id = #{@member.id} and stories.id = review_summary.story_id and review_summary.num_answers >= 3 group by format(review_summary.rating, 1)"
    @rrd_data = fetch_data_and_generate_plot_data_arrays(query_string, [], opts) { |h, row| h[row[0].to_f] = row[1].to_i }

      # Reviews Rating Distribution -- split by story type and source ownership
    query_string = "select format(review_summary.rating, 1), stories.stype_code, count(*) from review_summary, stories where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and review_summary.member_id = #{@member.id} group by format(review_summary.rating, 1), stories.stype_code"
    plot_keys = [1,2,3,4] # the four stype_code keys in the db
    @rrd_by_stype_data = fetch_data_and_generate_plot_data_arrays(query_string, plot_keys, opts) { |h, row|
      h[row[1].to_i] ||= {}
      h[row[1].to_i][row[0].to_f] = row[2].to_i 
    }

      # Reviews Rating Distribution -- comparison by story type and source ownership
    opts.merge!({:normalize => true, :x_aggregate => true, :x_aggregate_reverse => true})
    @rrd_by_stype_comp_data = fetch_data_and_generate_plot_data_arrays(query_string, plot_keys, opts) { |h, row|
      h[row[1].to_i] ||= {}
      h[row[1].to_i][row[0].to_f] = row[2].to_i 
    }

      # Story reviews distribution -- split by story type and source ownership
    db_rows = Member.connection.select_rows("select stories.stype_code, count(*) from stories, reviews where stories.id = reviews.story_id and reviews.member_id = #{@member.id} group by stories.stype_code")
    stype_data = db_rows.inject({}) { |h,row| h[row[0].to_i] = row[1].to_i; h }
    @reviews_by_stype_data = get_plot_data_arrays((1..4), [], stype_data)
  end
  
  protected

  def find_member_through_activation_code
    self.current_member = params[:id].blank? ? false : Member.find_by_activation_code(params[:id])
    raise ActiveRecord::RecordNotFound unless self.current_member
    @member = current_member
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "<strong>Invitation Expired</strong>
    <p>The registration link you clicked to join #{APP_NAME} is no longer valid.  Perhaps you already activated your account via Facebook connect (or by clicking on the activation link previously)?</p>"
    redirect_to new_sessions_path
  end

  def find_member_and_verify_profile_access
    @member = (logged_in? && current_member.has_role_or_above?(:admin)) ? Member.find(params[:id]) : Member.active.find(params[:id])
    render_403(Member, "You do not have access to this member's profile page.") unless @member.is_visible? || member_is_owner_or_has_role?(:editor)
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No Member Found with id #{params[:id]}."
    redirect_to home_url
  end

  private

  def fetch_data_and_generate_plot_data_arrays(query_string, keys, opts = {})
      # Fetch data from the db!
    db_rows = ActiveRecord::Base.connection.select_rows(query_string)

      # Massage the data into a hash of x_val => y_val mappings
      # But, yield to the caller to process the db row
    data = db_rows.inject({}) { |h,row| yield h,row; h }

      # X-axis: 50 rating values on x-axis 0.1 apart
    xs = (0..50).collect { |x| x/10.0 }

      # Generate flot data array
    return get_plot_data_arrays(xs, keys, data, opts)
  end

  def get_reviews(num_reviews, commented_only = false, public_only = false)
    if public_only && !@member.has_public_profile?
      []
    else
      Review.find_member_reviews(@member, public_only ? false : member_is_owner_or_has_role?(:editor),
        :page => params[:page], :per_page => num_reviews, :commented_only => commented_only)
    end
  end

  def get_picks(num_picks, public_only = false)
    if public_only && !@member.has_public_profile?
      []
    else
      conditions = ["saves.member_id = ?", @member.id]
      if public_only
        conditions[0] += " AND stories.status in ('list', 'feature')"
      elsif !member_is_owner_or_has_role?(:editor)
        conditions[0] += " AND stories.status in ('pending', 'list', 'feature')"
      end
      Story.paginate(:all,
        :joins => 'JOIN saves ON stories.id=saves.story_id',
        :conditions => conditions,
        :limit => num_picks,
        :page => params[:page], :per_page => num_picks,
        :order => 'stories.story_date DESC')
    end
  end

  def get_submissions(num_picks, public_only = false)
    if public_only && !@member.has_public_profile?
      []
    else
      conditions = ["stories.submitted_by_id = ?", @member.id]
      if public_only
        conditions[0] += " AND stories.status in ('list', 'feature')"
      elsif !member_is_owner_or_has_role?(:editor)
        conditions[0] += " AND stories.status in ('pending', 'list', 'feature')"
      end
      Story.paginate(:all,
        :conditions => conditions,
        :limit => num_picks,
        :page => params[:page], :per_page => num_picks,
        :order => 'stories.created_at DESC')
    end
  end

  def output_widget(stories, link_to_tab, add_review_data, title_suffix)
    widget_params = {
      :listing_url   => link_to_tab ? request.url.sub(%r|/([^/]*).json$|, '#\1') : request.url.sub(/.json$/, ''),
      :listing_type  => nil,
      :listing_topic => "#{@member.name}'s #{title_suffix}"
    }
    widget = widgetize_listing(widget_params, stories, add_review_data)
    @metadata = widget[:metadata]
    @stories  = widget[:stories]
    if !@member.has_public_profile?
      @access_denied_msg = "#{@member.name}'s activity can only be viewed by registered #{APP_NAME} members. To see this member's activity, please signup (or login) on #{APP_NAME}, then visit <a href='#{member_url(@member)}'>#{member_url(@member)}</a>."
    end
    render :layout => false, :template => "widgets/widgets.json.erb"
  end

  def output_rss(rss_type, objects, builder_template)
    if @member.has_public_profile?
      params[:per_page] = 25 # FIXME: Parameterize this
      @feed_data = {
        :feed_title  => "#{@member.name}'s #{rss_type}",
        :listing_url => request.url.sub(/.xml$/, ''),
        :items       => objects
      }
      render :layout => false, :template => builder_template
    else
      @member_profile_url = member_url(@member)
      @access_denied_msg = "#{@member.name}'s activity can only be viewed by registered #{APP_NAME} members. To see this member's activity, please signup (or login) on #{APP_NAME}, then visit #{member_url(@member)}."
      render :layout => false, :template => "rss_feeds/access_denied.rss.builder"
    end
  end

  def member_is_owner_or_has_role?(role)
    (logged_in? and (current_member.has_role_or_above?(role) or current_member == @member))
  end

  def setup_network_activity
    @url_tracking_key = "nw"
    conds = [["member_id in (?)", @followed_members.map(&:id)]]
    conds << ["id < ?", params[:last_activity_entry_id]] if params[:last_activity_entry_id]
    @network_activity_entries = ActivityEntry.find(:all,
                                                   :conditions => QueryHelpers.conditions_array(conds),
                                                   :order => "updated_at DESC", 
                                                   :include => {:member => [:image, :facebook_connect_settings, :twitter_settings]},
                                                   :limit => SiteConstants::NUM_ACTIVITY_ENTRIES_PER_FETCH)
    ActivityEntry.reject_hidden_entries(@network_activity_entries)
    @network_activity_hash = ActivityEntry.activity_object_hash(@network_activity_entries)
  end

  def setup_followed_members_activity
    @url_tracking_key = "nw"
    @followed_members = @member.followed_members.sort { |a,b| a.name <=> b.name }
    @followed_members_activity_entries = @followed_members.collect { |f| ActivityEntry.most_recent_member_activity(f) }
# SSS FIXME: View for followed_members relies on entries in this array being in the same order as the @followed_members array
# Plus, if we reject hidden entries, we need to replace it with something else in its place given how this tab works
#
#    ActivityEntry.reject_hidden_entries(@followed_members_activity_entries)
#
    @followed_members_activity_hash = ActivityEntry.activity_object_hash(@followed_members_activity_entries)
  end

  def setup_followers_activity
    @url_tracking_key = "nw"
    @followers = @member.followers.sort { |a,b| a.name <=> b.name }
    @followers_activity_entries = @followers.collect { |f| ActivityEntry.most_recent_member_activity(f) }
# SSS FIXME: View for followers relies on entries in this array being in the same order as the @followers array
# Plus, if we reject hidden entries, we need to replace it with something else in its place given how this tab works
#
#    ActivityEntry.reject_hidden_entries(@followers_activity_entries)
#
    @followers_activity_hash = ActivityEntry.activity_object_hash(@followers_activity_entries)
  end
end
