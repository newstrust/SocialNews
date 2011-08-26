class TwitterController < ApplicationController
  include OpenidProfilesHelper
  include SessionsHelper
  include PartnersHelper
  include TwitterHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  ## For now, we are not implementing twitter connect -- only getting twitter credentials to read from twitter and post to twitter
  before_filter :login_required

  ## Twitter Oauth Plugin client for getting authenticated tokens from twitter
  @@oauth_client = TwitterSettings.oauth_client
  @@oauth_config = TwitterSettings.oauth_config

  def connect
    m = current_member 
    if m && m.twitter_connected?
      flash[:notice] = "Your Twitter and #{APP_NAME} accounts have been linked!"
      redirect_to home_url
    end
  end

  def authenticate
    request_token = @@oauth_client.request_token(:oauth_callback => @@oauth_config['callback_url'])
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
	  redirect_to request_token.authorize_url
  rescue Net::HTTPFatalError
    flash[:error] = "Twitter is timing out, please try again later"
    redirect_to home_url
  rescue Errno::ECONNRESET => e
    flash[:error] = "Twitter is timing out, please try again later"
    redirect_to home_url
  rescue Errno::ETIMEDOUT => e
    flash[:error] = "Twitter is timing out, please try again later"
    redirect_to home_url
  rescue OAuth::Unauthorized => e
    flash[:error] = "Twitter did not accept your account credentials. Are you sure you typed them correctly?"
    redirect_to home_url
  end

  def activate
    # Exchange the request token for an access token.
    @access_token = @@oauth_client.authorize(
      session[:request_token],
      session[:request_token_secret],
      :oauth_verifier => params[:oauth_verifier]
    )

    if @@oauth_client.authorized?
      # Link the NT and twitter accounts
      current_member.twitter_link(@access_token)

      # Done!
      flash[:notice] = "Your Twitter and #{APP_NAME} accounts are now linked!"
      render :layout => "minimal"
    else
      flash[:error] = "We are sorry! Twitter did not accept your account credentials or you denied us access. <a style='text-decoration:underline;font-weight:bold' href='#{twitter_authenticate_path}'>Do you want to try again?</a>"
      redirect_to home_url
    end
  rescue OAuth::Unauthorized
    flash[:error] = "Either you denied us access to your Twitter account or we encountered an unexpected error with your credentials.  If the latter, <a style='text-decoration:underline;font-weight:bold' href='#{twitter_authenticate_path}'>please try again!</a>"
    redirect_to home_url
  rescue SocketError
    flash[:error] = "The connection with Twitter timed out. <a style='text-decoration:underline;font-weight:bold' href='#{twitter_authenticate_path}'>Please try again!</a>"
    redirect_to home_url
  rescue Errno::ECONNRESET
    flash[:error] = "The connection with twitter got reset.  <a style='text-decoration:underline;font-weight:bold' href='#{twitter_authenticate_path}'>Let us try once more</a>.  If this problem persists, please email us at #{SocialNewsConfig["email_addrs"]["feedback"]}."
    redirect_to home_url
  rescue Net::HTTPFatalError
    flash[:error] = "We've encountered an error connecting with twitter.  Please try your request later."
    redirect_to home_url
  end

  def unlink
    current_member.twitter_unlink
    flash[:notice] = "Successfully unlinked your Twitter and #{APP_NAME} accounts."
    redirect_to my_account_members_path + "#account"
  end

  def follow_newsfeed
    m = current_member
    f = nil
    connected = m.twitter_connected?

    respond_to do |format|
      format.js {
        if connected
          f = m.twitter_settings.add_newsfeed
          render :json => {:unconnected => false, :feed => {:icon => f.favicon, :name => f.name, :id => f.id, :url => feed_path(f) }}.to_json 
        else
          render :json => {:unconnected => true}.to_json 
        end
      }
    end
  end

  def unfollow_newsfeed
    m = current_member
    f = m.twitter_newsfeed
    FollowedItem.delete_all(:follower_id => m.id, :followable_type => 'Feed', :followable_id => f.id)
    flash[:notice] = "You are no longer following your Twitter newsfeed"
    redirect_to mynews_url(m)
  rescue Exception => e
    logger.error "Exception unfollowing twitter newsfeed for #{m.name}"
  end

  def followable_friends
    m = current_member
    error = nil
    followable_members = []
    if !m.twitter_connected?
      error = "twitter_unconnected"
    else
      base = m.twitter_followable_friends
      if base.empty?
        error = "twitter_no_friends"
      else
        followable_members = base - m.followed_members
        if followable_members.blank?
          error = "twitter_no_more_friends"
        end
      end
    end

    respond_to do |format|
      format.js do
        render :json => { :error => error, :members => followable_members.collect { |m| {:id => m.id, :name => m.name, :icon => m.small_thumb} } }.to_json
      end
    end
  end
end
