# This is an attempt to bypass rails altogether to reduce memory consumption.
# A spawner spins up a process which runs this ruby code to fetch the feed, parse it, and posts errors / stats to the server.
#
# - On a 64-bit server, this ruby code can run in under 100 mb whereas a single rake task that loads up
#   the whole rails environment uses up about 300 mb.
# - On a 32-bit server, this ruby code can run in under 30 mb whereas a single rake task that loads up
#   the whole rails environment uses up about 100+ mb.
#
# So, this is 3-5x more memory efficient.

require 'rubygems'
require 'system_timer'
require 'feed-normalizer'
require 'net/http'
require 'open-uri'
require 'hpricot'
require 'mysql'
require "#{File.dirname(__FILE__)}/custom_twitter_feed_processors"
require "#{File.dirname(__FILE__)}/metadata_fetcher"
require "#{File.dirname(__FILE__)}/net_helpers"
require "#{File.dirname(__FILE__)}/string_helpers"
require "#{File.dirname(__FILE__)}/url_fixup_rules"
require "#{File.dirname(__FILE__)}/sap_helpers"

class FeedParser
  include SapHelpers
  include UrlFixupRules

  MAX_STORY_STALENESS    = 3 * 24 * 3600 # 3 days
  FF_KEY                 = "nt_ff_2010"
  STORY_POST_PATH        = "stories/feed_fetcher_post"
  FEED_FETCH_STATUS_PATH = "feeds/feed_fetch_status"
  NUM_FETCHED_FEEDS_PATH = "feeds/num_completed_feeds"

  @@rails_env = "development"  # Default!

  def self.rails_env; @@rails_env; end

  attr_accessor :dbc

  def initialize(opts={})
    @@rails_env    = opts[:rails_env]      || "development"
    @server_url    = opts[:server_url]     || "http://localhost:3000"
    mysql_server   = opts[:mysql_server]   || "localhost"
    mysql_user     = opts[:mysql_user]     || "root"
    mysql_password = opts[:mysql_password] || ""
    mysql_db       = opts[:mysql_db]       || "socialnews"
    begin
      if !opts[:no_dbc]
        @dbc = Mysql.real_connect(mysql_server, mysql_user, mysql_password, mysql_db)
        StoryStub.dbc = @dbc
      end
    rescue Exception => e
      STDERR.puts "Exception opening db connection #{e}.  Quitting!"
      exit
    end
  end

  def shutdown
     @dbc.close if @dbc
  end

  def num_completed_feeds
    uri = "#{@server_url}/#{NUM_FETCHED_FEEDS_PATH}?api_key=#{FF_KEY}"
    response = Net::HTTP.get_response(URI.parse(uri))
    response.body.to_i
  end

  def fetch_and_parse(feed_params)
    id  = feed_params[:id]
    url = feed_params[:url]
    hp  = feed_params[:home_page]
    is_twitter_feed           = !((url =~ /twitter.com/).nil?)
    is_fb_user_newsfeed       = !((url =~ /facebook.com.*dummy_newsfeed_url/).nil?)
    is_twitter_user_newsfeed  = !((url =~ /twitter.com.*dummy_newsfeed_url/).nil?)
    is_regular_feed = !(is_twitter_feed || is_fb_user_newsfeed)
    start_time = Time.now
    if is_fb_user_newsfeed
      require "#{File.dirname(__FILE__)}/facebook_connect"
      url = FacebookConnect.fb_activity_stream_url(url)
    end
    if is_twitter_user_newsfeed
      require "ostruct"
      require "#{File.dirname(__FILE__)}/twitter_connect"
      client = TwitterConnect.authed_twitter_client(url)

      # Map twitter entries to an open struct with same fields as produced by a regular rss parser!  
      ps = client.home_timeline.collect { |e|
        OpenStruct.new({:title => e.text,
                        :date_published => Time.parse(e.created_at),
                        :description => e.text,
                        :id => e.id,
                        :urls => [],
                        :authors => "",
                        :categories => []})
      }
    else
      ps = parsed_stories(url)
    end
    ps.each { |fe|
      if is_twitter_feed
        twitterer = hp ? hp.gsub(%r|http://[^/]*/|, "") : ""
        if (CustomTwitterFeedProcessors.respond_to?("#{twitterer}_process_feed_entry"))
          fe_url = CustomTwitterFeedProcessors.send("#{twitterer}_process_feed_entry", fe)
        else
            # FIXME: Assuming there is only one match! -- use scan if you want all matches
          fe_url = fe.title.match(%r|http://[^\s]*|) 
        end
        fe_url = fe_url.to_s if fe_url
      elsif is_fb_user_newsfeed
        fe_url = fe.urls[0]
          # If we the url is a facebook-local url, look for a url within the title of the post
          # FIXME: Assuming there is only one match! -- use scan if you want all matches
        fe_url = fe.title.match(%r|http://[^\s]*|) if (fe_url =~ %r|facebook.com/|)
        fe_url = fe_url.to_s if fe_url
      else
        fe_url = fe.urls[0]
      end

      # Ignore images, movies, pdfs, word files!
      if fe_url.nil? || ad_image_or_ignoreable?(fe_url) || (fe_url !~ %r|^https?://([^/?#]+\.)+[^/?#]+(/[^/?#]*)*/?(\?([^#]*))?(#(.*))?|i)
        puts "--> Ignoring #{fe_url}"
        next
      end

      # Not all uris tend to be valid - they may have special characters!  So, deal with this!
      fe_url = URI.escape(fe_url)

      # Don't bother with stories that are older than X number of days
      pub_date = fe.date_published
      next if pub_date && (Time.now - pub_date) > MAX_STORY_STALENESS

      # Ignore NT stories
      domain = NetHelpers.get_url_domain(fe_url)
      next if (domain =~ /#{@server_url}/)

      # Create the story object
      params = { :url       => fe_url,
                    # ignore titles & descriptions from twitter and facebook newsfeeds
                 :title     => (!is_regular_feed || fe.title.nil?) ? nil : StringHelpers.plain_text(fe.title),
                 :excerpt   => (!is_regular_feed || fe.description.nil?) ? nil : StringHelpers.plain_text(fe.description),
                 :feed_id   => id,
                 :feed_cats => fe.categories * "|" }
      params[:journalist_names] = fe.authors * "," if !(is_fb_user_newsfeed || fe.authors.nil? || fe.authors.empty?)
      params[:story_date] = pub_date if is_regular_feed && pub_date

      # This also queries the db, and if found, sets the story id, and updates the url to the url
      # found in the db.  If this is a new story, id will be nil.
      s = StoryStub.new(params)
      orig_url = s.url
      next if s.story_date && (Time.now - s.story_date) > MAX_STORY_STALENESS

      if s.id.nil?
        # * If we have a twitter feed, query Tweetmeme's API before the url is canonicalized.
        #   We are more likely to get a hit if we use the original shortened url from the twitter stream
        # * Don't query daylife with twitter urls - they will fail!  
        #   For others, handle Daylife specially.  Daylife doesn't use canonical urls.
        #   So, first try with the original url. If we don't get a hit, dont store the result
        #   so that we query daylife once more later with the new url.
        if !is_regular_feed
          MetadataFetcher.get_api_metadata(s, :tweetmeme, {:refresh => false, :store_if_empty => false})
        else
          MetadataFetcher.get_api_metadata(s, :daylife, {:refresh => false, :store_if_empty => false})
        end

        # Follow proxies and get target url
        begin
          s.url = NetHelpers.get_target_url(CGI.unescape(s.url)).strip
        rescue Exception => e
          STDERR.puts e
        end

        # Fetch the story body and dump into the db!
        begin
          s.url, s.body = NetHelpers.fetch_content(s.url)
        rescue Exception => e
          STDERR.puts "While fetching story content for #{s.url}, got an error: #{e.message}"
        end

        # The url of the story might have changed after following proxies .. so, look in the db again!
        s.get_id_from_url
      end

      # From UrlFixupRules -- extracts target urls from toolbars & proxies
      begin
        orig = s.url
        cleanup_url(s)
        s.get_id_from_url if orig != s.url # Look in the db again if the url has changed!
      rescue Exception => e
        STDERR.puts "While cleaning up url for #{s.url}, got an error: #{e.message}"
      end

      # get/refresh metadata
      MetadataFetcher.query_all_apis(s)

      # check if we have fresh metadata for an existing story
      if s.id
        most_recent_md_update_time = MetadataFetcher::APIS.keys.collect { |api| s.metadata_update_time(api) }.max
        has_fresh_md = (Time.now - most_recent_md_update_time) < 3600
      end

      # Post to the server if:
      # (a) this is in pending status
      # (b) this is a new story or has some fresh metadata or has a new story_feed entry
      if (s.status == "pending") && (s.id.nil? || has_fresh_md || s.has_new_feed_entries)
        params[:api_key] = FF_KEY
        params[:url] = s.url
        resp = Net::HTTP.post_form(URI.parse("#{@server_url}/#{STORY_POST_PATH}"), params)
        s.id = resp.body.to_i
        if s.id
          s.description = fe.description
          s.dump_to_db(resp.code == "201")  # status code 201 is returned for new stories
          s.record_alternate_url(orig_url) if (orig_url != s.url)
        end
      end
    }
    success = true
    error   = nil
  rescue FetchFailed => e 
    success = false
    error   = e.to_s
    STDERR.puts "ERROR fetching feed #{id}: #{error}; #{e.backtrace.inspect}"
  rescue Exception => e
    success = false
    error   = e.to_s
    STDERR.puts "Exception #{e} fetching feed #{id}; #{e.backtrace.inspect}"
  ensure
    params = {
      :api_key    => FF_KEY,
      :feed_id    => id,
      :start_time => start_time,
      :end_time   => Time.now,
      :success    => success,
      :error      => error
    }
    count = 0
    resp = nil
    while (count < 5 && (resp.nil? || resp.class != Net::HTTPOK)) do
      resp = Net::HTTP.post_form(URI.parse("#{@server_url}/#{FEED_FETCH_STATUS_PATH}"), params)
      count += 1
    end
    return 0
  end

  private 

  def parsed_stories(feed_url)
    max_retries = 5
    tries = 0
    begin
      content = (feed_url =~ %r|facebook.com.*activitystreams|) ? NetHelpers.fetch_content(feed_url)[1] : open(feed_url)
      parsed_feed = nil

      # Looks like for some feeds, they are not getting parsed at all and the CPU is pegged at 100% stuck in some kind of an infinite loop!
      # We might have to upgrade the feed-normalizer gem to tackle this.  Till then, use the timeout strategy to handle this problem.
      # 2 minutes is sufficiently long to parse a rss feed.
      SystemTimer::timeout(120) {
        parsed_feed = FeedNormalizer::FeedNormalizer.parse(content, :loose => true)
      }
      if parsed_feed.nil?
        raise FetchFailed.new("Failed to fetch and parse rss feed (url: #{feed_url})")
      else
        parsed_feed.entries
      end
    rescue Exception => e
      tries += 1
      STDERR.puts "Exception #{e}"
      if tries < max_retries
        STDERR.puts "TRY #{tries}: Previous attempt failed ... Retrying fetch & parse of feed #{feed_url}"
        retry 
      else
        raise e
      end
    end
  end

  class FetchFailed < StandardError; end

  class StoryStub
    attr_accessor :id, :url, :title, :status, :story_date, :journalist_names, :body, :description, :excerpt, :debug_excerpt, :feed_id, :feed_cats, :has_new_feed_entries
    MetadataFetcher::APIS.keys.each { |api| attr_accessor api.to_s + "_info" }

    def self.dbc=(x); @@dbc = x; end
    def self.dbc; @@dbc; end

    def initialize(params)
      params.each { |k,v| self.send("#{k.to_s}=", v) }
      self.id = get_id_from_url
      update_story_feed_entries if self.id && self.feed_id
    end

    def update_story_feed_entries
      res = @@dbc.query("SELECT id FROM story_feeds WHERE story_id=#{self.id} AND feed_id=#{self.feed_id}")
      if (res.num_rows == 0)
        stmt = "INSERT INTO story_feeds(story_id,feed_id) VALUES(#{self.id},#{self.feed_id})"
        @@dbc.query(stmt)
        self.has_new_feed_entries = true
      else
        self.has_new_feed_entries = false
      end
    end

    def get_id_from_url
      url    = @@dbc.escape_string(self.url)
      res    = @@dbc.query("SELECT id,status,story_date FROM stories WHERE url='#{url}'")
      id     = nil
      status = "pending"
      sd     = nil
      res.each_hash { |row| id = row["id"]; status = row["status"]; sd = row["story_date"] }
      if id.nil?
        res = @@dbc.query("SELECT stories.id, stories.url, stories.status, stories.story_date FROM stories JOIN story_urls ON story_urls.story_id=stories.id WHERE story_urls.url='#{url}'")
        new_url = nil
        res.each_hash { |row| id = row["id"]; new_url = row["url"]; status = row["status"]; sd = row["story_date"] }
        self.url = new_url if !new_url.nil?
      end
      begin
        self.status = status
        self.story_date = Time.parse(sd) if !sd.nil?
      rescue Exception => e
        STDERR.puts "Exception #{e} parsing story date #{sd} for story #{id}"
      end
      id ? id.to_i : nil
    end

    def load_attribute(fld, col_name="value")
      val = nil
      if self.id
        res = @@dbc.query("SELECT #{col_name} FROM story_attributes WHERE name='#{fld}' AND story_id=#{self.id}")
        res.each_hash { |row| val = row[col_name] }
      end
      val
    end

    def store_attribute(fld, val)
      if self.id && !val.nil?
        val = @@dbc.escape_string(val)
        now = Time.now.strftime("%Y-%m-%d %H:%m:%S")
        res = @@dbc.query("SELECT id FROM story_attributes WHERE story_id=#{self.id} AND name='#{fld}'")
        if res.num_rows == 0
          stmt = "INSERT INTO story_attributes(story_id,name,value,created_at,updated_at) VALUES(#{self.id},'#{fld}','#{val}','#{now}','#{now}')"
        else
          stmt = "UPDATE story_attributes SET value='#{val}', updated_at='#{now}' WHERE story_id=#{self.id} AND name='#{fld}'"
        end
        @@dbc.query(stmt)
      end
    end

    def api_metadata(api)
      @metadata ||= {}
      v = @metadata[api]
      if (v.nil?)
        v_str = load_attribute(api.to_s + "_info") # Fetch from db
        if (!v_str.nil?)
            # convert hex nibbles to binary and then unmarshall the binary data
          v = Marshal.load([v_str].pack("H*"))
          @metadata[api] = v # cache it
        end
      end
      v
    rescue Exception => e
      nil
    end

    def record_api_metadata(api, v)
      @metadata ||= {}
      @metadata[api] = v
        # since marshalling generates binary data .. convert it to hex nibbles using unpack
        # because I am lazy to create a new binary table for api info
      store_attribute(api.to_s + "_info", Marshal.dump(v).unpack("H*")[0]) if !v.nil?
    end

    def metadata_update_time(api)
      s = load_attribute(api.to_s + "_info", "updated_at")
      s.nil? ? nil : Time.parse(s)
    end

    def record_alternate_url(alt_url)
      if (self.id && !alt_url.nil?)
        val = @@dbc.escape_string(alt_url)
        stmt = "INSERT INTO story_urls(story_id,url,created_at) VALUES(#{self.id},'#{val}','#{Time.now.strftime("%Y-%m-%d %H:%m:%S")}')"
        @@dbc.query(stmt)
      end
    end

    def dump_to_db(new_story)
      MetadataFetcher::APIS.keys.each { |api| record_api_metadata(api, api_metadata(api)) }
      if new_story
        self.body ||= ""
        max_size = 512*1024 # 512kb
        body = self.body.slice(0,max_size) if self.body.length > max_size
        body = @@dbc.escape_string(self.body)
        desc = self.description.nil? ? "" : @@dbc.escape_string(self.description)
        stmt = "UPDATE auto_fetched_stories SET description='#{desc}', body='#{body}'WHERE story_id=#{self.id}"
        @@dbc.query(stmt)
      end
    end
  end
end
