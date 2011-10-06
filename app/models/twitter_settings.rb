require 'twitter_oauth'

class TwitterSettings < ActiveRecord::Base
  belongs_to :member
  
  twitter_config = "#{RAILS_ROOT}/config/twitter.yml"
  if File.exists?(twitter_config)
    begin
      @@oauth_config = YAML.load(ERB.new(File.read(twitter_config)).result)[RAILS_ENV] 
      @@oauth_client = TwitterOAuth::Client.new(:consumer_key => @@oauth_config['consumer_key'], :consumer_secret => @@oauth_config['consumer_secret']) if @@oauth_config
    rescue Exception => e
      logger.error "Error initializing Twitter support: #{e}; #{e.backtrace.inspect}"
    end
  end

  def self.oauth_client; @@oauth_client; end
  def self.oauth_config; @@oauth_config; end

  def authed_twitter_client
    if self.access_token
      if !@client
        oauth = Twitter::OAuth.new(@@oauth_config['consumer_key'], @@oauth_config['consumer_secret'])
        oauth.authorize_from_access(self.access_token, self.secret_token)
        @client = Twitter::Base.new(oauth)
      end
      @client
    end
  end

  def add_newsfeed
    m = self.member
    f = m.twitter_newsfeed
    # Do not store feed url in the db! Not that it matters for twitter.
    dummy_url = "http://twitter.com/dummy_newsfeed_url/#{self.access_token}/#{self.secret_token}"
    if f.nil?
      f = Feed.create(:url => dummy_url, :auto_fetch => true, :name => "#{m.name}'s Twitter Feed", :member_profile_id => m.id, :feed_type => Feed::TW_UserNewsFeed)
    else
      f.update_attributes({:auto_fetch => true, :url => dummy_url})
    end
    fi = FollowedItem.add_follow(m.id, 'Feed', f.id)

    # If a new follow, queue this feed for immediate fetch so that the user has 'instant gratification'!
    Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:fetch_feed feed_id=#{f.id} submitter_id=#{m.id}" if !fi.nil?

    return f
  end

  def twitter_friend_ids
    cl = authed_twitter_client
    cl ? cl.friend_ids : []
  rescue Exception => e
  end

  def twitter_follower_ids
    cl = authed_twitter_client
    cl ? cl.follower_ids : []
  rescue Exception => e
  end
end
