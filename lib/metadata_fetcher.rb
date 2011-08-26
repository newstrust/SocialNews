require 'xml'
require 'net/http'
require 'cgi'
require 'system_timer'
require "#{File.dirname(__FILE__)}/api/daylife"

module MetadataFetcher
  if !defined?(SocialNewsConfig)
    require 'logger'
    require 'yaml'
    mydir = File.dirname(__FILE__)
    @logger = Logger.new("#{mydir}/../log/metadata_fetcher.log")
    SocialNewsConfig = File.open("#{mydir}/../config/social_news_constants/api_keys.yml") { |yf| YAML::load( yf ) }
  else
    @logger = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}_metadata_fetcher.log")
    @logger.formatter = RailsFormatter.new
  end

    # Ordering important -- used in the get_story_excerpt method
    # NOTE: Not using the refetch & rating options yet -- but added them in case we want to later on
  API_ARRAY = [ {:api => :daylife,   :opts => { :rating => 1, :retry_if_empty => true, :retry_delay => 12*3600} },
                {:api => :digg,      :opts => { :rating => 1, :refresh_after => 12*3600 } },
                {:api => :tweetmeme, :opts => { :rating => 1, :retry_if_empty => true, :retry_delay => 12*3600 } },
                {:api => :facebook,  :opts => { :rating => 1, :retry_if_empty => true, :retry_delay => 2*3600 } } ]
  APIS = API_ARRAY.inject({}) { |h,a| h[a[:api]] = a[:opts]; h }

    # Timeout period for any api
  API_TIMEOUT_PERIOD = 10

  public

  # So that this file can be used in rails-free ruby code
  def self.blank(s)
      s.nil? || ([String,Hash,Array].include?(s.class) && s.empty?)
  end

  def self.get_digg_count(story)
    get_api_metadata(story, :digg)[:digg_count]
  end

  def self.get_tweet_count(story)
    get_api_metadata(story, :tweetmeme)[:tweet_count]
  end

  def self.get_fb_popularity_count(story)
    get_api_metadata(story, :facebook)[:total_count]
  end

  def self.get_story_date(story)
    query_apis_and_get_data(story, :date)
  end

  def self.get_story_authors(story)
    query_apis_and_get_data(story, :authors)
  end

  def self.get_story_excerpt(story)
    query_apis_and_get_data(story, :excerpt)
  end

  def self.get_story_tags(story)
    query_apis_and_get_data(story, :tags, false) || []
  end

  def self.get_story_title(story)
    query_apis_and_get_data(story, :title)
  end

  def self.get_mapped_topics(tag)
    API_ARRAY.collect { |a| api = a[:api]; MetadataFetcher.const_get(api.to_s.capitalize).send("get_mapped_topics", tag) }.compact.flatten
  end

  def self.query_all_apis(story)
    API_ARRAY.each { |a| get_api_metadata(story, a[:api]) }
  end

  ## Count how many apis have an entry for this story
  def self.get_api_listing_count(story)
    query_all_apis(story)
    API_ARRAY.inject(0) { |sum, a| api = a[:api]; sum + (story.api_metadata(api)[:title].nil? ? 0 : 1) }
  end

  def self.get_api_metadata(story, api, options = {})
    options[:store_if_empty] = true if options[:store_if_empty].nil?
    options[:refresh]        = true if options[:refresh].nil?
    api_info = story.api_metadata(api)
    if !blank(APIS[api]) && (api_info.nil? || (options[:refresh] && should_refetch_metadata(story, api_info, api)))
      api_info = eval("MetadataFetcher::#{api.to_s.capitalize}").send("get_metadata", story) || {}
      story.record_api_metadata(api, api_info) if !blank(api_info) && (options[:store_if_empty] || !api_info[:empty])
    end
    api_info
  end

  private

    ## ------- Helper methods below ----------
  def self.logger; @logger; end

  def self.get_attribute_value(node, key)
    node[0] ? node[0].attributes[key] : nil
  end

  def self.get_content(node, child_name, nstag="", ns=nil)
     c = node.find(nstag+child_name, ns)
     c = c[0] if !c.nil?
     c ? c.content : nil
  end

  def self.get_response(url, api)
    SystemTimer::timeout(API_TIMEOUT_PERIOD) {
      http_response = NetHelpers.get_response(url)
      case http_response
        when Net::HTTPSuccess then http_response.body
        else 
          if (api.downcase.to_sym == :tweetmeme)
            raise Tweetmeme::RateLimitExceeded.new("Got #{http_response.code}: #{http_response.message}")
          else
            raise Exception.new("Exception accessing #{api} API service: Got #{http_response.code}: #{http_response.message}")
          end
      end
    }
  end

  def self.should_refetch_metadata(story, api_info, api)
    now = Time.now

      # Refetch if empty
    if api_info[:empty] && APIS[api][:refetch_if_empty]
      t = story.metadata_update_time(api) # t can be nil if this is a new story!
      return true if t && (now - t > APIS[api][:retry_delay])
    end

      # Refresh if necessary
    if APIS[api][:refresh_after]
      t = story.metadata_update_time(api) # t can be nil if this is a new story!
      return true if t && (now - t > APIS[api][:refresh_after])
    end

    return false
  end

  # This method queries as many apis as necessary to fetch the required story data -- it stops after the data is found!
  # This method is used by the front end to keep response as quick as possible.
  def self.query_apis_and_get_data(story, key, only_one = true)
    key = key.to_sym
    res = []

    API_ARRAY.each { |a|
      api = a[:api]
      api_info = get_api_metadata(story, api, {:refresh => false})
      val = api_info[key]
      if !blank(val)
        story.debug_excerpt = api.to_s if key == :excerpt  # Add debug info!
        MetadataFetcher.logger.info "For #{story.url}, found #{key} from #{api}"
        res += [val]
          ## Stop as soon as you find the desired value!
        break if only_one
      end
    }

    only_one ? res[0] : res.flatten
  end

  private # No direct access to the api classes

    ## ------- Daylife md fetcher, uses the Daylife API library --------
  class Daylife
    @api = ::Daylife::API.new(SocialNewsConfig["daylife"]["api_key"],SocialNewsConfig["daylife"]["shared_secret"])

    def self.get_mapped_topics(tag); []; end

    def self.get_metadata(story)
      SystemTimer::timeout(API_TIMEOUT_PERIOD) {
        resp = @api.execute('article', 'getInfo', :url => story.url)
        if resp && resp.articles && resp.articles.size > 0
          art = resp.articles[0]
          retval = { :title       => StringHelpers.plain_text(art.headline),
                     :excerpt     => StringHelpers.plain_text(art.excerpt),
                     :date        => art.timestamp,
                     :source_name => art.source ? art.source.name : nil }
          topicResp = @api.execute('article', 'getTopics', :url => story.url)
          retval[:tags] = topicResp.topics.map { |t| t.name } if topicResp && topicResp.topics && topicResp.topics.size > 0
          return retval
        else
          return { :empty => true }
        end
      }
    rescue Exception => e
      MetadataFetcher.logger.error "Exception fetching daylife metadata for #{story.url}: #{e}\n"
      return { :empty => true }
    end
  end

    ## ------- DIGG md fetcher, no API library for now since we are only making a single call --------
  class Digg
    DEFAULT_SERVER = "http://services.digg.com"

      ## Map from Digg categories to SocialNews topics 
      ## Use lower-case topic names!
    TOPIC_MAP = {
      "world_news|world_business" => ["world"],
      "space|science|tech_news|technology" => ["sci/tech"],
    }

    def self.get_mapped_topics(tag)
       match = TOPIC_MAP.find { |re, tn| tn if tag =~ /^#{re}$/i }
       match ? match[1] : nil
    end

    def self.get_mapped_topics_or_tag(tag)
      get_mapped_topics(tag) || tag.downcase
    end

    def self.stories_endpoint_response(args)
      args[:appkey] = SocialNewsConfig["digg"]["api_key"]
      param_string  = args.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join("&")
      http_response = MetadataFetcher.get_response("#{DEFAULT_SERVER}/stories?#{param_string}", "DIGG")
    end

    def self.story_endpoint_response(args)
      args[:appkey] = SocialNewsConfig["digg"]["api_key"]
      digg_url = $1 if args[:link] =~ %r|.*/([^/]*)$|
      digg_url.gsub!(%r|\?.*|, '')
      args.delete(:link)
      param_string = args.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join("&")
      http_response = MetadataFetcher.get_response("#{DEFAULT_SERVER}/story/#{digg_url}?#{param_string}", "DIGG")
    end

    def self.parse_response(resp, get_link = false)
      doc = XML::Parser.string(resp, :options => XML::Parser::Options::NOENT | XML::Parser::Options::NOBLANKS).parse
      s   = doc.find("//stories/story")
      if (s.size > 0)
        s = s[0]
        tags = []

          # Topic
        x = s.find("topic")
        x = x[0] if x
        x = x.attributes["short_name"] if x
        tags << x if x

          # Subject
        x = s.find("container")
        x = x[0] if x
        x = x.attributes["short_name"] if x
        tags << x if x

        retval = { :title => StringHelpers.plain_text(MetadataFetcher.get_content(s, "title")),
                   :excerpt => StringHelpers.plain_text(MetadataFetcher.get_content(s, "description")),
# We are no longer using digg's tags
#                   :tags  => tags.collect { |t| get_mapped_topics_or_tag(t) },
                   :digg_count => s.attributes["diggs"].to_i }
        retval.merge!({ :link => s.attributes["link"] }) if get_link
        return retval
      else
        return { :empty => true }
      end
    end

    def self.get_metadata(story)
      args = {:link => story.url}
      if (story.url =~ /digg.com/)
        parse_response(story_endpoint_response(args), true)
      else
        parse_response(stories_endpoint_response(args), false)
      end
    rescue Exception => e
      MetadataFetcher.logger.error "Exception fetching digg metadata for #{story.url}: #{e}"
      return { :empty => true }
    end
  end

    ## ------- Tweetmeme md fetcher, no API library for now since we are only making a single call --------
  class Tweetmeme
    URL_PREFIX = "http://api.tweetmeme.com/url_info?url="

    @@next_attempt_time = File.exists?("/tmp/tw.backoff.time") ? Time.parse(File.open("/tmp/tw.backoff.time") { |fh| fh.read }) : Time.now

    class RateLimitExceeded < StandardError; end

    def self.get_mapped_topics(tag); []; end

    def self.get_metadata(story)
      if (Time.now < @@next_attempt_time)
        MetadataFetcher.logger.error "Will not hit Tweetmeme till #{@@next_attempt_time}"
        return { :empty => true }
      end

      resp = MetadataFetcher.get_response("#{URL_PREFIX}#{CGI.escape(story.url)}", "Tweetmeme")
      doc  = XML::Parser.string(resp, :options => XML::Parser::Options::NOENT | XML::Parser::Options::NOBLANKS).parse
        # Extract attributes
      ni = doc.find("//story")
      if (ni.size != 0)
        ni = ni[0]
        return { :url         => MetadataFetcher.get_content(ni, "url"),
                 :title       => MetadataFetcher.get_content(ni, "title"),
# We are no longer using tweetmeme's excerpts
#                 :excerpt     => MetadataFetcher.get_content(ni, "excerpt"),
                 :tweet_count => MetadataFetcher.get_content(ni, "url_count").to_i }
      else
        return { :empty => true }
      end
    rescue RateLimitExceeded
      MetadataFetcher.logger.error "Tweetmeme Rate Limit exceeded.  Backing off for 5 minutes!"
      @@next_attempt_time = Time.now + 300  # try again in 5 minutes!  Do not use 5.minutes because this has to work in plain Ruby!
      File.open("/tmp/tw.backoff.time", "w") { |fh| fh.write @@next_attempt_time }
      return { :empty => true }
    rescue Exception => e
      MetadataFetcher.logger.error "Exception fetching tweetmeme metadata for #{story.url}: #{e}"
      return { :empty => true }
    end
  end

    ## ------- Facebook md fetcher, no API library for now since we are only making a single call --------
  class Facebook
    URL_PREFIX = "http://api.facebook.com/restserver.php?method=links.getStats&urls="

    def self.get_mapped_topics(tag); []; end

    def self.get_metadata(story)
      resp = MetadataFetcher.get_response("#{URL_PREFIX}#{CGI.escape(story.url)}", "Facebook")
      doc  = XML::Parser.string(resp, :options => XML::Parser::Options::NOENT | XML::Parser::Options::NOBLANKS).parse
        # Extract attributes
      ns = "fb:http://api.facebook.com/1.0/"
      ni = doc.find("//fb:link_stat", ns)
      if (ni.size != 0)
        ni = ni[0]
        return { :url           => MetadataFetcher.get_content(ni, "url", "fb:", ns),
                 :share_count   => MetadataFetcher.get_content(ni, "share_count", "fb:", ns).to_i,
                 :like_count    => MetadataFetcher.get_content(ni, "like_count", "fb:", ns).to_i,
                 :comment_count => MetadataFetcher.get_content(ni, "comment_count", "fb:", ns).to_i,
                 :total_count   => MetadataFetcher.get_content(ni, "total_count", "fb:", ns).to_i}
      else
        return { :empty => true }
      end
    rescue Exception => e
      MetadataFetcher.logger.error "Exception fetching Facebook metadata for #{story.url}: #{e}"
      return { :empty => true }
    end
  end
end
