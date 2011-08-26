class FacebookConnectController < ApplicationController
  include OpenidProfilesHelper
  include SessionsHelper
  include PartnersHelper
  include FacebookConnectHelper

  APP_NAME = SocialNewsConfig["app"]["name"]
  FB_NEW_INVITE_CODE  = "FBC"
  FB_LINK_INVITE_CODE = "FBL"
  FB_MIN_VALIDATION_LEVEL = 1

  before_filter :login_required, :only => [:link_member, :unlink, :import_picture, :invite_friends, :record_invitations, :unfollow_newsfeed ]
  before_filter { |controller| controller.send(:use_partner_layout) if controller.params['partner_id'] }

  def init_activation
    session[:fb_activated] = true
    url_prefix = @invitation ? "/partners/#{@partner.to_param}/#{@invitation.to_param}" : ""
    redirect_to "#{url_prefix}#{fb_activate_path}#{params[:popup] ? '?popup=true' : ''}"
  end

  def activate
    # To avoid leaking FB credentials, eliminate all 3rd party content
    @no_third_party_content = true

    # SSS: This either finds the member by existing app session id, facebook uid, or by email hash
    # NOTE: Find by email hash only succeeds if we've previously registered accounts with Facebook
    # We are not doing this right now.  So, it is not really very useful.  But, there in anticipation of the
    # time when we decide to do that.

    if facebook_session.nil?
      flash[:error] = "Have you logged out of Facebook?  Please login into Facebook and try again"
      redirect_to new_sessions_path and return
    end

    fb_user = facebook_session.user
    m = current_member || Member.find_by_email_hash(fb_user.email_hashes)
    if m
        # We have a story id if we come from the story toolbar!
      if params[:story_id] && (s = Story.find(params[:story_id]))
        link_opts = { :go => session[:dupe_reviews].blank? ? :review : :dupe_reviews }
        link_opts[:popup] = true if params[:popup]
        session[:return_to] = toolbar_story_path(s, link_opts)
      end

      if current_member.fb_uid
        flash[:notice] = "You have been logged in with your Facebook account"
        if session[:return_to] =~ /mynews/
          flash[:notice] += "<div id='fixup_notice'><br/><a style='color:#4a4' href='#{session[:return_to]}'>Click here to go to your MyNews page</a></div>"
        end
        @invitation.group.process_join_request(current_member) if @invitation && @invitation.group
        @local_site.process_signup(current_member) if @local_site
        redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, home_url)
      else
          ## We aren't connected yet
        flash[:notice] = "<div id='fixup_notice'><a style='color:#4a4' href='/fb_connect/activate'>Please click here to continue with Facebook Connect.</a></div>"
        @member = current_member
        @follow_user_stream = params[:follow_user_stream]
        render({:template => 'facebook_connect/link_confirmation'}.merge(params[:popup] ? {:layout => "popup"} : {}))
      end
    else
      flash[:notice] = "<div id='fixup_notice'><a style='color:#4a4' href='/fb_connect/activate'>Please click here to proceed with signup.</a></div>"
      name = fb_user.name
      dup = Member.find_by_name(name)
      @name_conflict = !dup.nil?
      @member = Member.new(:name => name, :status => "guest", :email => nil) # Guest status
      render({:template => 'facebook_connect/signup'}.merge(params[:popup] ? {:layout => "popup"} : {}))
    end
  rescue Facebooker::Session::SessionExpired => e
    logger.error "Expired session?!?"
    flash[:error] = "Have you logged out of Facebook?  Please login into Facebook and try again."
    redirect_to new_sessions_path
  rescue Exception => e
    logger.error "Exception #{e} trying to activate! #{e.backtrace.inspect}"
    flash[:error] = "We encountered an error and will take a look at this as soon as possible.  Please ensure that you are logged into Facebook and try again.  If this error persists, please email us at #{SocialNewsConfig["email_addrs"]["feedback"]} and we will take a look."
    redirect_back_or_default(logged_in? ? my_account_members_path : new_sessions_path)
  end

  def new_account
    cookies.delete :auth_token # SSS: Why is this being done?
    @member = Member.find_by_email(params[:member][:email])
    if @member
      flash[:notice] = "You already have a #{APP_NAME} account registered to #{@member.email}!  Enter your password below to link that account to your Facebook account."
      redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true&email=#{@member.email}" : "?email=#{@member.email}")
    else
      # SSS FIXME: Maybe rename :newsletter to :newsletter_subscription_attrs to avoid this fixup?
      params[:member][:newsletter_subscription_attrs] = params[:member].delete(:newsletter)
      @member = Member.new(params[:member].merge(new_member_params))
      @member.record_request_env(request.env)
      @member.accept_invitation(@invitation) if @invitation

      link_fb_and_nt(@member, FB_NEW_INVITE_CODE, true)

      # Yes, it is self.current_member=, not current_member=
      self.current_member = @member
      flash[:notice] = "Thanks for signing up!  You are now a #{APP_NAME} member -- and linked to Facebook."
      @partner.members << @member if @partner
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, "/welcome")
    end
  rescue ActiveRecord::RecordInvalid
    @name_conflict = true
    render({:template => 'facebook_connect/signup'}.merge(params[:popup] ? {:layout => "popup"} : {}))
  rescue Facebooker::Session::SessionExpired => e
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
    redirect_to new_sessions_path
  end

  def link_accounts
    if facebook_session
      fb_user = facebook_session.user
      @member = Member.new(:name => fb_user.name, :email => params[:email])
      render :layout => "popup" if params[:popup]
    else
      flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
      redirect_back_or_default(new_sessions_path)
    end
  rescue Facebooker::Session::SessionExpired => e
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
    redirect_to new_sessions_path
  end

  def login_and_link
    self.current_member = Member.authenticate(params[:member][:email], params[:member][:password])
    if logged_in?
      link_fb_and_nt(current_member, FB_LINK_INVITE_CODE, (current_member.status == 'guest'))
      flash[:notice] = "Your Facebook and #{APP_NAME} accounts have been linked!"
      if request.env["HTTP_REFERER"] =~ /popup=true/
        render :template => "facebook_connect/popup_close", :layout => "minimal"
      else
        redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, home_url)
      end
    else
      flash[:error] = 'Invalid login or password'
      redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true" : "")
    end
  rescue Facebooker::Session::SessionExpired => e
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
    redirect_back_or_default(new_sessions_path)
  rescue Exception => e
    logger.error "Exception: #{e}; #{e.backtrace.inspect}"
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again. If that doesn't do the trick, please email #{SocialNewsConfig["email_addrs"]["help"]} and we'll take a look!"
    redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true" : "")
  end

  def logout
    delete_session
    @fb_logout_redirect_url = params[:return_to]
    @fb_logout_redirect_url = home_url if @fb_logout_redirect_url.blank?
    session[:return_to] = nil
    render :layout => "fb_minimal"
  end

  def link_member
    link_fb_and_nt(current_member, FB_LINK_INVITE_CODE, (current_member.status == 'guest'))
    flash[:notice] = "Your Facebook and #{APP_NAME} accounts have been linked!"
    if request.env["HTTP_REFERER"] =~ /popup=true/
      render :template => "facebook_connect/popup_close", :layout => "minimal"
    else
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, home_url)
    end
  rescue Facebooker::Session::SessionExpired => e
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
    redirect_back_or_default(new_sessions_path)
  rescue Exception => e
    logger.error "Exception: #{e}; #{e.backtrace.inspect}"
    flash[:error] = "Have you logged out of #{APP_NAME}?  Please login and try again!"
    redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true" : "")
  end

  def import_picture
    m = current_member
    pic_url = fb_profile_pic_url
    if pic_url
      m.image = Image.download_from_url(pic_url)
      m.save(false)
    else
      flash[:notice] = "We could not find a Facebook profile picture to download."
    end
    redirect_to my_account_members_path + "#picture"
  end

  def cancel
    session[:fb_activated] = false
    redirect_to home_path
  end

  def unlink
    session[:fb_activated] = false
    m = current_member
    m.fbc_unlink
    flash[:notice] = "Successfully unlinked your Facebook and #{APP_NAME} accounts.<br/>If you originally signed up via Facebook, change your password below to login to #{APP_NAME} in the future."
    redirect_to my_account_members_path + "#account"
  end

  def invite_friends
    eids = facebook_session ? facebook_session.user.friends_with_this_app.map(&:id) + current_member.facebook_invitations.map(&:fb_uid) : []
    @exclude_ids = eids * ", "
    render({:template => 'facebook_connect/invite_friends'}.merge(params[:popup] ? {:layout => "popup"} : {}))
  end

  def record_invitations
    params["ids"].each { |fb_id| current_member.facebook_invitations << FacebookInvitation.create(:fb_uid => fb_id) } if params["ids"]
    redirect_to home_path
  end

  def followable_friends
    m = current_member
    error = nil
    followable_members = []
    if facebook_session.nil?
      error = "fb_logged_out"
    elsif !m.fbc_linked?
      error = "fb_unconnected"
    else
      base = m.fbc_followable_friends(facebook_session)
      if base.empty?
        error = "fb_no_friends"
      else
        followable_members = base - m.followed_members
        if followable_members.blank?
          error = "fb_no_more_friends"
        end
      end
    end

    respond_to do |format|
      format.js do
        render :json => { :error => error, :members => followable_members.collect { |m| {:id => m.id, :name => m.name, :icon => m.small_thumb} } }.to_json
      end
    end
  end

  def unfollow_newsfeed
    m = current_member
    f = m.fbc_newsfeed
    FollowedItem.delete_all(:follower_id => m.id, :followable_type => 'Feed', :followable_id => f.id)
    flash[:notice] = "You are no longer following your Facebook newsfeed"
    redirect_to mynews_url(m)
  rescue Exception => e
    logger.error "Exception unfollowing fb newsfeed for #{m.name}"
  end

  def update_extended_perms
    render :json => {:logged_out => true}.to_json and return if facebook_session.nil?

    m = current_member
    unconnected = false
    eps = params[:granted_perms]

    if !m.fbc_linked?
      # Since the user has not explicitly connected their accounts, link & unlink immediately so that we create 
      # a fbc record to store the granted permissions!  We dont want to lose them!
      unconnected = true
      m.fbc_link(facebook_session)
      m.fbc_unlink
    end

    # Store granted permissions
    fbc_settings = m.facebook_connect_settings
    if !eps.blank?
      eps.split(",").each { |p|
        p.strip!
        if p == "read_stream"
          fbc_settings.update_attribute(:ep_read_stream, 1)
        end

        if p == "offline_access"
          fbc_settings.update_attribute(:ep_offline_access, 1)
          fbc_settings.update_attribute(:offline_session_key, facebook_session.session_key)
        end
      }
    end

    respond_to do |format|
      format.js {
        if unconnected
          render :json => {:unconnected => true}.to_json 
        else
            # If we were previously unconnected, add the user's fb newsfeed (and follow it, if we aren't following it)
          f = fbc_settings.add_new_user_activity_stream_feed
          render :json => {:unconnected => false, :feed => {:icon => f.favicon, :name => f.name, :id => f.id, :url => feed_path(f) }}.to_json 
        end
      }
    end
  end

  private

  def new_member_params
      # Provide a dummy, but random, password to let validation succeed
    pass = Member.new_pass(8)

    { :password              => pass, 
      :password_confirmation => pass }
  end

  def fb_profile_pic_url
      # HACK to get a bigger picture
      # Change http://profile.ak.facebook.com/profile5/687/114/s592675411_3902.jpg to
      #        http://profile.ak.facebook.com/profile5/687/114/n592675411_3902.jpg     <-- Bigger picture 
    pic = facebook_session.user.pic
    pic.blank? ? nil : pic.sub(%r|/s(\d+_\d+\.\w+)$|, '/n\1')
  end

  def link_fb_and_nt(m, default_invite_code, activate_member)
      # FB linking members get assigned an invitation code so that they can be tracked
    m.invitation_code = m.invitation_code.blank? ? default_invite_code : "#{m.invitation_code}, #{default_invite_code}"

      # FB account-creation/linking members get their validation bumped up to FB_MIN_VALIDATION_LEVEL if they are less than that
    m.validation_level = FB_MIN_VALIDATION_LEVEL if m.validation_level < FB_MIN_VALIDATION_LEVEL

    if m.id.nil?
      m.save!  # We want validations to run!
    else
      m.save(false) # No validations to run
    end

      # Activate the member -- no need to wait for them to use the email to activate
    m.activate_without_save if activate_member

    # Link
    m.fbc_link(facebook_session)

      # Import photo if required
    if params[:import_fb_photo]
      pic_url = fb_profile_pic_url
      m.image = Image.download_from_url(pic_url) if pic_url
    end

    if params[:read_stream]
      m.facebook_connect_settings.update_attribute(:ep_read_stream, 1)
    end

    if params[:offline_access]
      m.facebook_connect_settings.update_attribute(:ep_offline_access, 1)
      m.facebook_connect_settings.update_attribute(:offline_session_key, facebook_session.session_key)
    end

    # Add a follow of the Facebook user stream of the current user
    m.facebook_connect_settings.add_new_user_activity_stream_feed if params[:follow_user_stream]

      # Process autofollows!
    m.fbc_autofollow_friends = 1 if params[:autofollow_friends]
    af = m.fbc_autofollow_friends?
    fb_friends_on_nt.each { |f| # clearly, if we have linked with fbc, m is same as the member with the active facebook session
      m.follow_member(f) if af
      f.follow_member(m) if f.fbc_autofollow_friends?  # On facebook, friendship is a symmetric/reciprocal relationship
    }

    # Add member to group!
    @invitation.group.process_join_request(m) if @invitation && @invitation.group
    @local_site.process_signup(m) if @local_site

    # Save -- no validations to run and process it in the background
    m.save(false)
    m.process_in_background
  end
end
