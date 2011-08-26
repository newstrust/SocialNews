class FacebookConnectSettings < ActiveRecord::Base
  belongs_to :member

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
