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

  def logout
    delete_session
    target_url = params[:return_to]
    target_url = home_url if target_url.blank?
    # Get the active access token and delete the oauth cookie
    # NOTE: Since this hits FB, this could potentially lock up the server
    # Could think of protecting this with a SystemTimer::timeout(5)
    access_token = FacebookConnectSettings.get_access_token(cookies)
    cookies.delete "fbsr_#{FacebookConnectSettings.app_id}"
    if access_token.nil?
      flash[:notice] = "You have been logged out."
      redirect_to target_url
    else
      flash[:notice] = "You have been logged out of #{APP_NAME} as well as Facebook."
      redirect_to "https://www.facebook.com/logout.php?next=#{CGI.escape(target_url)}&access_token=#{access_token}"
    end
  end

  def activate
    # To avoid leaking FB credentials, eliminate all 3rd party content
    @no_third_party_content = true

    # In case the cancel button on the facebook dialog gets us here (as it does on staging & development sandboxed FB apps)
    fb_user = current_facebook_user
    if fb_user.nil?
      flash[:notice] = "Facebook login cancelled."
      redirect_to new_sessions_path
      return
    end

    m = current_member || Member.find_by_email(fb_user["email"])
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
      name = fb_user["name"]
      dup = Member.find_by_name(name)
      @name_conflict = !dup.nil?
      @member = Member.new(:name => name, :status => "guest", :email => nil) # Guest status
      render({:template => 'facebook_connect/signup'}.merge(params[:popup] ? {:layout => "popup"} : {}))
    end
  rescue Exception => e
    logger.error "Exception #{e} trying to activate! #{e.backtrace.inspect}"
    flash[:error] = "We encountered an error and will take a look at this as soon as possible.  Please ensure that you are logged into Facebook and try again.  If this error persists, please email us at #{SocialNewsConfig["email_addrs"]["feedback"]} and we will take a look."
    redirect_back_or_default(logged_in? ? my_account_members_path : new_sessions_path)
  end

  def new_account
    cookies.delete :auth_token # SSS: Delete the remember_me cookie
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

      self.current_member = @member
      flash[:notice] = "Thanks for signing up!  You are now a #{APP_NAME} member -- and linked to Facebook."
      @partner.members << @member if @partner
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, "/welcome")
    end
  rescue ActiveRecord::RecordInvalid
    @name_conflict = true
    render({:template => 'facebook_connect/signup'}.merge(params[:popup] ? {:layout => "popup"} : {}))
  rescue Exception => e
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
    redirect_to new_sessions_path
  end

  def link_accounts
    fb_user = current_facebook_user
    if fb_user
      @member = Member.new(:name => fb_user["name"], :email => params[:email])
      render :layout => "popup" if params[:popup]
    else
      flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again."
      redirect_back_or_default(new_sessions_path)
    end
  rescue Exception => e
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
  rescue Exception => e
    logger.error "Exception: #{e}; #{e.backtrace.inspect}"
    flash[:error] = "Have you logged out of Facebook? Login to Facebook and try again. If that doesn't do the trick, please email #{SocialNewsConfig["email_addrs"]["help"]} and we'll take a look!"
    redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true" : "")
  end

  def link_member
    link_fb_and_nt(current_member, FB_LINK_INVITE_CODE, (current_member.status == 'guest'))
    flash[:notice] = "Your Facebook and #{APP_NAME} accounts have been linked!"
    if request.env["HTTP_REFERER"] =~ /popup=true/
      render :template => "facebook_connect/popup_close", :layout => "minimal"
    else
      redirect_to_back_or_default(@invitation && !@invitation.success_page_link.blank? ? @invitation.success_page_link : nil, home_url)
    end
  rescue Exception => e
    logger.error "Exception: #{e}; #{e.backtrace.inspect}"
    flash[:error] = "Have you logged out of #{APP_NAME}?  Please login and try again!"
    redirect_to fb_link_accounts_url + (params[:popup] ? "?popup=true" : "")
  end

  def import_picture
    m = current_member
    pic_url = fb_profile_pic_url(m)
      # Since this is a public profile picture, there is no need to jump through security hoops.
      # So, just fetch the picture on a regular HTTP connection.
      # With HTTPS, we need to make sure we have valid security certificates.
    if pic_url
      m.image = Image.download_from_url(pic_url)
      m.save(false)
      flash[:notice] = "Your Facebook profile picture has been imported."
    else
      flash[:notice] = "We could not find a Facebook profile picture to download."
    end
    redirect_to my_account_members_path + "#picture"
  rescue Exception => e
    logger.error "Exception importing picture from Facebook for #{m.id}:#{m.name}; #{e}; #{e.backtrace.inspect}"
    flash[:error] = "We ran into an error importing your picture from Facebook.  Please try again and let us know if this problem persists."
  end

  def cancel
    session[:fb_activated] = false
    redirect_to home_path
  end

  def unlink
    session[:fb_activated] = false
    m = current_member
    m.fbc_unlink
    flash[:notice] = "Successfully unlinked your Facebook and #{APP_NAME} accounts.<br/>If you originally signed up via Facebook, change your password below if you wish to login to #{APP_NAME} in the future."
    redirect_to my_account_members_path + "#account"
  end

  def invite_friends
    eids = facebook_session ? current_member.fb_app_friends(facebook_session).map(&:id) + current_member.facebook_invitations.map(&:fb_uid) : []
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
          fbc_settings.update_attribute(:offline_session_key, facebook_session["access_token"])
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

  def fb_profile_pic_url(m)
    count = 0
    begin
      pic_url = m.facebook_connect_settings.api_client(facebook_session["access_token"]).get_picture("me", :type => :large)
      pic_url.gsub!(/https/, "http") if pic_url
      pic_url
    rescue Koala::Facebook::APIError => e
      logger.error "ERROR: Could not import FB profile picture for #{m.id}.  Exception:#{e};  BT: #{e.backtrace.inspect}"
      count += 1
      retry if count < 2
      flash[:error] = "We are sorry! We could not import your profile picture at this time. We have logged the error and will look into it.  But, please try again later."
    end
  end

  def link_fb_and_nt(m, default_invite_code, activate_member)
      # FB linking members get assigned an invitation code so that they can be tracked
    m.invitation_code = m.invitation_code.blank? ? default_invite_code : "#{m.invitation_code}, #{default_invite_code}"

      # FB account-creation/linking members get their validation bumped up to FB_MIN_VALIDATION_LEVEL if they are less than that
    m.validation_level = FB_MIN_VALIDATION_LEVEL if m.validation_level < FB_MIN_VALIDATION_LEVEL

    # Link before save so that the member observer knows that the member is fbc linked!
    m.fbc_link(facebook_session)
    if m.id.nil?
      m.save!  # We want validations to run!
    else
      m.save(false) # No validations to run
    end

      # Activate the member -- no need to wait for them to use the email to activate
    m.activate_without_save if activate_member

    # cache friendship info!
    m.cache_facebook_friendship_info(facebook_session)

    access_token = facebook_session["access_token"]

      # Import photo if required
    if params[:import_fb_photo]
      pic_url = fb_profile_pic_url(m)
      m.image = Image.download_from_url(pic_url) if pic_url
    end

    if params[:read_stream]
      m.facebook_connect_settings.update_attribute(:ep_read_stream, 1)
    end

    if params[:offline_access]
      m.facebook_connect_settings.update_attribute(:ep_offline_access, 1)
      m.facebook_connect_settings.update_attribute(:offline_session_key, access_token)
    end

    # Add a follow of the Facebook user stream of the current user
    m.facebook_connect_settings.add_new_user_activity_stream_feed if params[:follow_user_stream]

      # Process autofollows!
    m.fbc_autofollow_friends = 1 if params[:autofollow_friends]
    af = m.fbc_autofollow_friends?
    m.fb_app_friends(access_token).each { |f| # clearly, if we have linked with fbc, m is same as the member with the active facebook session
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
