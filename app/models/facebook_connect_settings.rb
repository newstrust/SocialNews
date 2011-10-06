class FacebookConnectSettings < ActiveRecord::Base
  belongs_to :member
  
  facebook_config = "#{RAILS_ROOT}/config/facebook.yml"
  if File.exists?(facebook_config)
    @@oauth_config = YAML.load(ERB.new(File.read(facebook_config)).result)[RAILS_ENV] 
    if @@oauth_config
      Koala.http_service.http_options[:ssl] ||= {}
      Koala.http_service.http_options[:ssl][:ca_path] = @@oauth_config["ssl_cert_path"]
      @@oauth_client = Koala::Facebook::OAuth.new(@@oauth_config['app_id'], @@oauth_config['secret']) 
    end
  end

  class << self
    def oauth_client; @@oauth_client; end

    def app_id; @@oauth_config["app_id"]; end

    def callback_url; @@oauth_config["callback_url"]; end

    def in_sandbox_mode?; @@oauth_config["sandbox_mode"]; end

    def get_user_info_from_cookies(cookies)
      @@oauth_client.get_user_info_from_cookie(cookies)
    rescue Exception => e
      nil
    end

    def get_access_token(cookies)
      facebook_cookies = @@oauth_client.get_user_info_from_cookie(cookies)
      return nil if facebook_cookies.nil?
      facebook_cookies["access_token"]
    rescue Exception => e
      nil
    end
  end

  # self.access_token may not always be current except when offline-access has been granted, which is rare.
  # We are not actively updating access_token anywhere at this time -- but if we did, it would be in
  # lib/authenticated_system.rb
  def api_client(access_token=self.access_token)
    if access_token
      @@api_client ||= Koala::Facebook::API.new(access_token)
    else
      @@api_client ||= nil
    end
  rescue Exception => e
    nil
  end

  def rest_api_client(access_token)
    api_client(access_token)
  end

  def graph_api_client(access_token)
    api_client(access_token)
  end

  def rest_api_call(access_token, rest_method, args={})
    rest_api_client(access_token).rest_call(rest_method, args)
  end

  # FIXME: This is no longer functional!
  #
  # Rather than use stream.get, we are going to use the activity stream format to read a user's stream
  #     http://wiki.developers.facebook.com/index.php/Using_Activity_Streams
  # This lets us fold facebook user streams into regular rss feed parsing code and makes things simpler!
  def add_new_user_activity_stream_feed
    f = nil

    # Require both 'read_stream' and 'offline_access' extended permissions!
    m = self.member
    if ep_read_stream && ep_offline_access
      f = m.fbc_newsfeed
      # Do not store feed url in the db!
      dummy_url = "http://facebook.com/dummy_newsfeed_url/#{self.fb_uid}/#{self.offline_session_key}"
      if f.nil?
        f = Feed.create(:url => dummy_url, :auto_fetch => true, :name => "#{m.name}'s Facebook Feed", :member_profile_id => m.id, :feed_type => Feed::FB_UserStream)
      else
        f.update_attributes({:auto_fetch => true, :url => dummy_url})
      end
      fi = FollowedItem.add_follow(m.id, 'Feed', f.id)

      # If a new follow, queue this feed for immediate fetch so that the user has 'instant gratification'!
      Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:fetch_feed feed_id=#{f.id} submitter_id=#{m.id}" if !fi.nil?
    end

    return f
  end
end
