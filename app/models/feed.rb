class Feed < ActiveRecord::Base
  validates_presence_of :url
  validates_uniqueness_of :url
  has_many :story_feeds, :dependent => :delete_all
  has_many :stories, :through => :story_feeds
  has_many :followed_items, :as => :followable
  has_many :followers, :through => :followed_items

  FB_UserStream   = "FB_UserStream"
  TW_UserNewsFeed = "TW_UserNewsFeed"

  MIN_AUTOLIST_SCORE     = SocialNewsConfig["queue_status_min_score"]
  TODAYS_FEEDS_MIN_SCORE = SocialNewsConfig["todays_feeds_min_score"]

  def self.regular_feeds_finder_condition
    ["auto_fetch = ? && (feed_type IS NULL OR feed_type NOT IN (?))", true, [Feed::FB_UserStream, Feed::TW_UserNewsFeed]]
  end

  def test
    require 'lib/feed_fetcher'
    FeedFetcher.parsed_stories(self)
  end

  def display_name
    is_twitter_user_newsfeed? ? name.sub(/'s Twitter Feed/, '') + " (t)" \
                              : (is_fb_user_newsfeed? ? name.sub(/'s Facebook Feed/, '') + " (f)" : (name || ""))
  end

  def is_twitter_feed?
    @itf ||= !((url =~ /twitter.com/).nil?)
  end

  def is_fb_user_newsfeed?
    feed_type == FB_UserStream
  end

  def is_twitter_user_newsfeed?
    feed_type == TW_UserNewsFeed
  end

  def is_nonmember_twitter_feed?
    is_twitter_feed? && !is_twitter_user_newsfeed?
  end

  def is_private?
    is_fb_user_newsfeed? || is_twitter_user_newsfeed?
  end

  def is_regular_feed?
    @irf ||= !(is_twitter_feed? || is_fb_user_newsfeed?)
  end

#  ## FIXME: Temporary 40% boost for twitter feeds!
#  def feed_level
#    (self.attributes["feed_level"] * (is_twitter_feed? ? 1.4 : 1.0)).round
#  end

  def can_read_fb_newsfeed?
    if is_fb_user_newsfeed?
      # SSS FIXME: not upgraded yet. This technique of reading via an ATOM feed no longer works.
      #
      # fb_uid, sess_key = $1, $2 if self.url =~ %r|dummy_newsfeed_url/(.*)/(.*)|
      # session = Facebooker::Session.create
      # session.secure_with!(sess_key, fb_uid)
      # ["offline_access", "read_access"].all? { |ep| session.post('facebook.users.hasAppPermission', {:ext_perm => ep, :uid => fb_uid }, false) == "1" }
      false
    else
      false
    end
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception figuring out if facebook feed url #{url} is readable by the feed fetcher - assuming false. Exception is #{e}"
    false
  end

  def mark_fb_newsfeed_unreadable
    if is_fb_user_newsfeed?
      m = Member.find(member_profile_id)
      m.facebook_connect_settings.update_attributes({:ep_read_stream => 0, :ep_offline_access => 0})
      update_attribute(:auto_fetch, false)
    end
  end

  def fetch
    require 'lib/feed_fetcher'
    FeedFetcher.fetch_feed(self)
  rescue Exception => e
    # Check if we are a facebook newsfeed and if our permissions have expired!
    if is_fb_user_newsfeed? && !can_read_fb_newsfeed? 
      mark_fb_newsfeed_unreadable
      raise FacebookConnect::MissingPermissions.new
    else
      raise e
    end
  end

  def is_author_feed?
    fg = self.feed_group
    !fg.blank? && fg =~ /Author/i
  end

  def is_publication_feed?
    fg = self.feed_group
    !fg.blank? && fg =~ /Publication/i
  end

  def is_aggregator_feed?
    fg = self.feed_group
    !fg.blank? && fg =~ /Aggregator/i
  end

  def favicon
    return @favicon if @favicon

    # SSS FIXME: hardcoded paths below -- used in lib/favicon_scraper.rb too -- keep them consistent
    if is_fb_user_newsfeed?
      @favicon = "/images/ui/mynews/facebook_favicon16.png"
    elsif is_twitter_user_newsfeed?
      @favicon = "/images/ui/mynews/twitter_favicon16.png"
    else
      favicon_dir = "/images/feed_favicons"
      path = "#{favicon_dir}/feed_#{self.id}.png"
      @favicon = File.exists?("#{RAILS_ROOT}/public/#{path}") ? path : "/images/ui/feed_favicon.png"
    end
  end

  def feed_stories(which=:all, timespan=:all)
    if (which == :all)
      @all_stories ||= {}
      @all_stories[timespan] ||= (timespan == :all ? self.stories : get_listing(which, timespan, false))
    else
      @s ||= {}
      @s[which] ||= {}
      @s[which][timespan] ||= get_listing(which, timespan, false)

      return @s[which][timespan]
    end
  end

  def feed_stories_count(which=:all, timespan=:all)
    if (which == :all)
      @all_stories_count ||= {}
      @all_stories_count[timespan] ||= (timespan == :all ? self.stories.count : get_listing(which, timespan, true))
    else
      @stories_count ||= {}
      @stories_count[which] ||= {}
      @stories_count[which][timespan] ||= get_listing(which, timespan, true)
    end
  end

  def percentage_queued_stories(timespan=:all)
    feed_stories_count(:all, timespan) > 0 ? (feed_stories_count(:queued, timespan) * 100) / feed_stories_count(:all, timespan) : 0
  end

  def percentage_listed_stories(timespan=:all)
    feed_stories_count(:all, timespan) > 0 ? (feed_stories_count(:listed, timespan) * 100) / feed_stories_count(:all, timespan) : 0
  end

  protected

  def get_listing(which, timespan, count)
    # SSS FIXME: Verify?
    # SSS: A feed is not associated with a local site, a feed's listing contains stories it fetched
    Story.normalize_opts_and_list_stories(nil, :listing_type => (which == :queued) ? :queued_stories : :most_recent,
                                               :feed_id      => self.id,
                                               :paginate     => false,
                                               :story_status => (which == :all) ? Story::ALL_STATUS_VALUES : nil,
                                               :all          => !count,
                                               :timespan     => timespan, 
                                               :count_only   => count)
  end

  def avg_feed_rating
    Story.average(:rating,
                  :joins => "JOIN story_feeds ON story_feeds.feed_id = #{self.id} AND story_feeds.story_id = stories.id",
                  :conditions => ["status IN (?) AND reviews_count >= ?", [Story::LIST, Story::FEATURE], SocialNewsConfig["min_reviews_for_story_rating"]]) \
    || 0.0
  end

  def num_trusted_feed_stories
    Story.count(:joins => "JOIN story_feeds ON story_feeds.feed_id = #{self.id} AND story_feeds.story_id = stories.id",
                :conditions => ["status IN (?) AND reviews_count >= ?", [Story::LIST, Story::FEATURE], SocialNewsConfig["min_reviews_for_story_rating"]])
  end
end
