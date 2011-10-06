module TwitterHelper
  def update_tweet_with_short_url(tweet, long_url, short_url)
    url = $1 if tweet =~ %r|(http://[^\s]*)|
    if url.nil?
        # Either use the provided short url or shorten the long url if the provided short url is a social news url (which is not short)
      short_url = (!short_url.blank? && (short_url !~ /#{SocialNewsConfig["app"]["domain"]}/i)) ? short_url : ShortUrl.shorten_url(long_url) 
      tweet = "#{tweet[0..(138 - short_url.length)]} #{short_url}"
    end
    [tweet, short_url]
  end

  # SSS FIXME: Should we add this to the list of background tasks -- we now have 2 network calls holding up the review!
  def tweet_it(member, tweet)
    if member.twitter_settings
      url  = $1 if tweet =~ %r|(http://[^\s]*)|
      resp = member.twitter_settings.authed_twitter_client.update(tweet)
      tweet_id = resp["id"]
      tweet_url = "http://twitter.com/#{member.twitter_settings.tw_uid}/statuses/#{tweet_id}"
      notice = "Your tweet is posted @ <a href='#{tweet_url}'>#{tweet_url}</a>.  Please try again in a bit if didn't show up there."
#      success_test = url || tweet
#      if (resp["text"] =~ %r|#{success_test}|)
#        tweet_id = resp["id"]
#        tweet_url = "http://twitter.com/#{member.twitter_settings.tw_uid}/statuses/#{tweet_id}"
#        notice = "Your tweet is posted @ <a href='#{tweet_url}'>#{tweet_url}</a>"
#      else
#        tweet_id = nil
#        error = "We are sorry! Your tweet didn't go through.  Please try again, or email us so we can take a look at this!"
#        logger.error "Tweet #{tweet} with #{url} failed to go through for #{member.id}"
#      end
    else
      # SSS: We should never ever get here because the tweet option should never have been shown to the user in the first place!
      # But, just a safeguard!
      error = "We are sorry! You need to link your Twitter and #{SocialNewsConfig["app"]["name"]} accounts to post on Twitter.  Please visit your account page to do this!"
    end
    { :id => tweet_id, :error => error, :notice => notice }
  rescue Twitter::General
    { :error => "We are sorry! You have reached Twitter's 24-hour limits and cannot make any more posts today (See http://help.twitter.com/forums/10711/entries/15364 for more information)" }
  rescue Twitter::Unauthorized
    { :error => "We are sorry! We no longer have the authorization to tweet on your behalf!  <a href='#{twitter_authenticate_path}' style='color:green;font-weight:bold;' target='_blank'>Please click here to authorize us to tweet on your behalf.</a>" }
  rescue Exception => e
    logger.error "ERROR tweeting #{tweet} #{url} on behalf of #{member.id}!  Exception: #{e}; Backtrace: #{e.backtrace.inspect}"
    { :error => "We are sorry! We encountered an unknown error tweeting on your behalf.  The error has been logged and we'll look into this as soon as possible!" }
  end

  def is_twitter_follower?(m1, m2)
    #m1.twitter_connected? && m2.twitter_connected? ? m1.twitter_settings.authed_twitter_client.friendship_exists?(m1.twitter_settings.tw_id, m2.twitter_settings.tw_id) : false
    m1.twitter_follower?(m2)
  rescue Exception => e
    logger.error "ERROR fetching twitter friendship info for #{m1.id} and #{m2.id}!  Exception: #{e}; Backtrace: #{e.backtrace.inspect}"
    false
  end
end
