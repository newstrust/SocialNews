require 'rubygems'
require 'feed-normalizer'
require 'open-uri'
require 'hpricot'

# The parsed feed entries have the following fields:
# 
# @id             - url;
# @title          - Title;
# @date_published - Date of publication;
# @categories     - Topics (or tags)
# @urls           - ??
# @description    - Description (use as story quote);
# @content        - ;
# @parsed         - ;
# @last_updated   - ??
# @authors / author

class FeedFetcher

  class FetchFailed < StandardError; end

  @logger = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}_feedfetcher.log")
  @logger.formatter = RailsFormatter.new
  def self.logger; @logger; end

  def self.init_fetch
    @failed_fetches = []
    @queued_stories = []
  end

  def self.yield_to_higher_priority_job
    # Check if a higher priority task is waiting around -- if so, execute it first!
    job = Bj.table.job.find(:first, :conditions => ["state = ? and submitted_at < ? and priority > ?", "pending", Time.now, SocialNewsConfig["bj"]["priorities"]["feed_fetcher"]], :order => "priority DESC")
    t = nil
    if job
      begin
        @logger.info "INTERRUPT: Found higher priority task #{job.bj_job_id}:#{job.command} waiting to run ... Executing that now!"
        job.state = "running"
        job.started_at =  Time.now
        job.save!
        job.reload
          # Run the rake task in the current environment -- dont open up another rails environment and waste memory! 
        if (job.command =~ /rake/)
          (task, args) = $1, $2 if job.command =~ /rake RAILS_ENV=#{RAILS_ENV}\s*([^\s]*)\s*(.*)/
          @logger.info "INTERRUPT: Running #{task} within current rake task -- passing args #{args}"
            # re-enable the rating update task separately because it is invoked by the update_and_submit task
          Rake::Task["socialnews:ratings:update"].reenable

            # re-enable this task and invoke it -- without re-enabling, it won't run again because of how rake works (like make!)
          t = Rake::Task[task]
          t.reenable

            # Mimic command-line args by setting ENV params
          if !args.blank?
            args.split("\s").each { |s| kv = s.split("="); ENV[kv[0]] = kv[1] }
          end
          t.invoke
          @logger.info "INTERRUPT: Successfully completed #{job.bj_job_id}"
        else
          t = "DUMMY"
          @logger.info "INTERRUPT: Running in a separate process"
          system(job.command + " > /tmp/#{job.bj_job_id}.out 2> /tmp/#{job.bj_job_id}.err")
          st = $?
          @logger.info "INTERRUPT: Successfully completed #{job.bj_job_id}"
        end
      rescue Exception => e
        @logger.error "INTERRUPT: Exception \'#{e}\' executing the higher priority task #{job.bj_job_id}"
      end

      # If we actually had a task to run, update its state to completed ... 
      if !t.nil?
        job.state = "finished"
        job.finished_at = Time.now
        if st
          job.pid = st.pid
          job.exit_status = st.exitstatus
        else
          job.pid = -1
          job.exit_status = 0
        end
        job.save!
      end
    end
  end

  def self.autofetch_feeds
      # Randomize processing of feeds so that if we kill the feed fetcher, the same set of feeds is not processed all the time!
    init_fetch
    feeds = Feed.find(:all, :select => "id", :conditions => "auto_fetch = true").sort { |a,b| n = rand(10); n == 5 ? 0 : (n < 5 ? -1 : 1) }
    feeds.each { |f_id|
      f = Feed.find(f_id)
      @logger.info "--- Starting fetch of feed #{f.id}:#{f.name} at #{Time.now} ---"
      begin; stories = fetch_feed(f); rescue; end; 
      @logger.info "--- Done fetching of feed #{f.id}:#{f.name} at #{Time.now} ---"
      f.last_fetched_at = Time.now 
      f.last_fetched_by = Member.nt_bot.id
      f.save!
      yield_to_higher_priority_job
    }

    { :num_feeds => feeds.size, :failed_fetches => @failed_fetches, :queued_stories => @queued_stories }
  end

  def self.fetch_feed(feed)
    init_fetch if @failed_fetches.nil?
    begin
        # TODO: Add better exception handling, retries, etc.
      stories = fetch_feed_stories(feed)

        # Track # of successful fetches
      feed.success_count = feed.success_count ? 1 + feed.success_count : 1
      feed.save
      return stories
    rescue Exception => e
      @logger.error "Error processing feed! #{e.message}"
      @logger.error "Backtrace follows\n #{e.backtrace.inspect}"

      @failed_fetches << [feed.id, feed.name, e.message]

        # Track # of failed fetches
      feed.failure_count = feed.failure_count ? 1 + feed.failure_count : 1
      feed.save
      raise e
    end
  end

  def self.debug_output(stories)
    stories.each { |s| 
      print "URL: #{s.url}\nTITLE: #{s.title}\n"
      if (s.authorships.empty?)
        puts "SOURCE: -- not known --\n"
      elsif (s.authorships.first.source.name.nil?)
        puts "SOURCE URL: #{s.authorships.first.source.domain}\n"
      else
        puts "SOURCE: #{s.authorships.first.source.name}\n"
      end
      if (!s.tag_aggregate.nil?)
        puts "TAGS - #{s.tag_aggregate}\n"
      end
      print "EXCERPT: #{s.excerpt}\n"
      print "AUTHORS: #{s.journalist_names}\n"
      print "--------------------\n"
    }
  end

  # This module implements autolist scoring
  module Score
    SCORE_COEFFICIENTS = {}
    [:num_diggs, :num_tweets, :fb_popularity, :feed_popularity, :api_popularity, :source_quality, :missing_fields].each { |s|
      SCORE_COEFFICIENTS[s] = SocialNewsConfig["feed_fetcher_score_coefficients"][s.to_s]
    }

    API_DECAY_FACTOR = SocialNewsConfig["feed_fetcher"]["api_decay_factor"]
    FEED_DECAY_FACTOR = SocialNewsConfig["feed_fetcher"]["feed_decay_factor"]

    def self.source_quality_score(v); v; end
    def self.missing_fields_score(v); v; end

    # Cap api and feed popularity -- so, each additional api/feed counts less and less
    def self.feed_popularity_score(v); v > 0 ? (1-FEED_DECAY_FACTOR**v)/(1-FEED_DECAY_FACTOR) : 0; end
    def self.api_popularity_score(v); v > 0 ? (1-API_DECAY_FACTOR**v)/(1-API_DECAY_FACTOR) : 0; end

    # Dampen diggs, tweets, fb, and nt popularity -- alternatively, we could use capping strategy as with api and feed popularity above
    def self.num_diggs_score(v); Math.log(v+1); end
    def self.num_tweets_score(v); Math.log(v+1); end
    def self.fb_popularity_score(v); Math.log(v+1); end

## With these settings, a story that belongs to exactly 2 feeds with levels of 30; is found in exacty one api;
## has 1 missing field, belongs to a source with 3.75 rating; and has 1 digg, 1 tweet, 1 fb shares will have a score around 1.0

        ## Autolist score components
    def self.score_components(story)
        ## NOTE: Using authorships instead of sources because the story might not be in the database yet
        ## in which case sources (derived association value) will be nil!
      story_source = !story.authorships.empty? ? story.authorships.first.source : nil
      num_apis = MetadataFetcher.get_api_listing_count(story)
      reqd_fields = Story::LISTED_STORY_REQD_FIELDS

      { :num_diggs       => MetadataFetcher.get_digg_count(story) || 0,
        :num_tweets      => MetadataFetcher.get_tweet_count(story) || 0,
        :fb_popularity   => MetadataFetcher.get_fb_popularity_count(story) || 0,
        :api_popularity  => num_apis || 0,
        :feed_popularity => story.feeds.inject(0.0) { |s,f| 
          # Editor-picked twitter feeds get a 40% boost
          s + 1.0 + (f.feed_level || 0.0) * (f.is_twitter_feed? && !f.is_twitter_user_newsfeed? ? 1.4 : 1.0) / 100.0 
        },
                      ## Stories with sources over 3.25 have a greater likelihood of getting listed
                      ## Stories with sources under 3.25 need to work harder in other areas
                      ## Pending sources, no sources, or unrated sources are penalized 
                      ##    effective penalty of (2.25 - 3.25) * source_quality_coefficienct = -0.3
        :source_quality  => ((story_source && story_source.is_public? && story_source.rating > 0) ? story_source.rating : 2.25) - 3.25,
                      ## Num reqd - Num available
        :missing_fields  => reqd_fields.length - reqd_fields.inject(0) { |n, f| n + (story.send(f).blank? ? (FeedFetcher.logger.info "Missing #{f}"; 0) : 1) }
      }
    end

    def self.autolist_score(story)
      components = score_components(story)
      score = SCORE_COEFFICIENTS.keys.inject(0) { |s, c| s + (Score.send("#{c}_score", components[c]) * SCORE_COEFFICIENTS[c]) }

        ## Debugging info
      FeedFetcher.logger.info "\nFor story #{story.id} with url - #{story.url},\n #{Score::SCORE_COEFFICIENTS.keys.collect { |n| "\t" + n.to_s + "=" + components[n].to_s } * "\n" }\n\tTOTAL SCORE: #{score}"

        ## Store score in the db!
      Score::SCORE_COEFFICIENTS.keys.each { |k| story.send("autolist_#{k.to_s}=", components[k]) }
      story.autolist_score = score
      ActivityScore.boost_score(story, :feed_submit)

      [components, score]
    end
  end

  private

  def self.compute_autolist_score(story)
    MetadataFetcher.query_all_apis(story)
    Score.autolist_score(story)
  end

  def self.should_autolist_story?(story, feed = nil)
    components, score = compute_autolist_score(story)

      ## Stricter constraints for twitter feeds
    is_eligible =    (feed && feed.is_regular_feed?) \
                  || (story.feeds.to_ary.find { |f| f.is_regular_feed? }) \
                  || (story.primary_source && (story.primary_source.status != 'pending')) \
                  || (components[:feed_popularity] > 3) \
                  || ((md1 = story.api_metadata(:daylife)) && !md1[:empty])

      ## Autolist if the score is at least this and the story is eligible for autolisting!
    is_eligible && score >= Feed::MIN_AUTOLIST_SCORE
  end

  def self.process_feed_entry(url, feed, feed_entry)
      # Ignore images!
    return nil if (url =~ /(\.jpg|\.gif|\.png|\.bmp)$/)

      # Not all uris tend to be valid - they may have special characters!  So, deal with this!
    url = URI.escape(url)

      # Use check_for_duplicates instead of find_by_url because it checks for alternate urls
      # and any other custom logic for detecting duplicates
    story = Story.check_for_duplicates(url)
    if (story.nil?)
      (new_story, extra_info) = get_new_story(url, feed_entry, feed)

        ## Check once again because once we process the story, the url might have changed!
      story = Story.check_for_duplicates(new_story.url)
      if story.nil?
        new_story.save_and_process_with_propagation
        story = new_story
      end

        ## Add tags & topics to the story, if any were discovered
      if (extra_info && extra_info[:topics])
        story.bot_topics = extra_info[:topics]
      end
      if (extra_info && extra_info[:tags])
        extra_info[:tags].each { |t| story.tag_with(Tag.quote(Tag.curate(t)), :member_id => Member.nt_bot.id) }
      end
    end

    story
  rescue Exception => e
    @logger.error("Exception processing story #{url}: #{e}")
    @logger.error "Backtrace follows\n #{e.backtrace.inspect}"
    nil
  end

  def self.process_twitter_feed_entry(feed, feed_entry)
    twitterer = feed.home_page ? feed.home_page.gsub(%r|http://[^/]*/|, "") : ""
    if (CustomTwitterFeedProcessors.respond_to?("#{twitterer}_process_feed_entry"))
      url = CustomTwitterFeedProcessors.send("#{twitterer}_process_feed_entry", feed_entry)
    else
        # FIXME: Assuming there is only one match! -- use scan if you want all matches
      m = feed_entry.title.match(%r|http://[^\s]*|) 
      url = m.to_s if m
    end
    process_feed_entry(url, feed, feed_entry) if url
  end

  def self.process_fb_newsfeed_entry(feed, feed_entry) 
    # If the url is a facebook-local url, look for a url within the title of the post
    url = feed_entry.urls[0]
    if (url =~ %r|facebook.com/|)
        # FIXME: Assuming there is only one match! -- use scan if you want all matches
      m = feed_entry.title.match(%r|http://[^\s]*|) 
      url = m ? m.to_s : nil
    end
    process_feed_entry(url, feed, feed_entry) if url
  end

  def self.parsed_twitter_newsfeed_stories(feed)
    tc = Member.find(feed.member_profile_id).authed_twitter_client
    # Map twitter entries to an open struct with same fields as produced by a regular rss parser!  
    tc.home_timeline.collect { |e|
      OpenStruct.new({:title => e.text, :date_published => e.created_at, :description => e.text, :id => e.id, :urls => [], :authors => "", :categories => []})
    }
  rescue Exception => e
    []
  end

  def self.parsed_stories(feed)
    max_retries = 5
    tries = 0
    begin
      url = feed.is_fb_user_newsfeed? ? FacebookConnect.fb_activity_stream_url(feed.url) : feed.url
      content = (url =~ %r|facebook.com.*activitystreams|) ? NetHelpers.fetch_content(url)[1] : open(url)
      parsed_feed = FeedNormalizer::FeedNormalizer.parse(content, :loose => true)
      if parsed_feed.blank?
        raise FetchFailed.new("Failed to fetch and parse rss feed (url: #{url})")
      else
        parsed_feed.entries
      end
    rescue Exception => e
      tries += 1
      if tries < max_retries
        @logger.error "TRY #{tries}: Previous attempt failed ... Retrying fetch & parse of feed #{url}"
        @logger.error "#{e.backtrace.inspect}"
        retry 
      else
        raise e
      end
    end
  end

  def self.fetch_feed_stories(feed)
    nt_bot = Member.nt_bot
    stories = []
    (feed.is_twitter_user_newsfeed? ? parsed_twitter_newsfeed_stories(feed) : parsed_stories(feed)).each { |feed_entry|
      begin
        story = feed.is_twitter_feed? ? process_twitter_feed_entry(feed, feed_entry) \
                                      : feed.is_fb_user_newsfeed? ? process_fb_newsfeed_entry(feed, feed_entry) \
                                                             : process_feed_entry(feed_entry.urls[0], feed, feed_entry)

          ## Twitter feeds can return you empty stories
        next if story.nil? 

          ## Don't bother with stories that are older than 7 days! (looks like some stories don't have a valid story_date)
        next if story.story_date && (Time.now - story.story_date) > 7.days

          ## If we are processing the same feed, ignore the tags!
        if (feed.id && !story.feeds.exists?(feed.id))
            ## Add the feed to the list of feeds that this story belongs to
          story.feeds << feed 

          begin
            story.add_feed_tags(feed_entry.categories)
          rescue Exception => e
            @logger.error "Caught exception processing story #{story.id}: #{e}"
            @logger.error "Backtrace follows\n #{e.backtrace.inspect}"
          end
        end

          ## SSS FIXME: These assume national topics
          ## Set up default topics if it has no topic or subject taggings
          ## New policy starting with mynews: Always add default topic tags that editors have set up no matter what the feeds give us.
        story.bot_topics = Tag.find_all_by_slug(feed.default_topics.split(",")) if !feed.default_topics.blank?

          ## Set up default story type if it doesn't already have one by now
        story.story_type = feed.default_stype if story.story_type.blank? && !feed.default_stype.blank?

          ## Check if we should auto-list this story
        if (story.status == Story::PENDING) && should_autolist_story?(story, feed)
          @logger.info "---- AUTOLISTING STORY #{story.id} ----"
          story.status = Story::QUEUE
          @queued_stories << story
        end

          # Save any additional information (autoflex attributes, topics, etc.) that was added/updated
        story.save
        stories << story
      rescue Exception => e
        @logger.error "Error processing feed_entry: Story is #{story ? story.id : 'nil'}.  #{e.backtrace.inspect}"
      end
    }

    return stories
  end

  def self.get_new_story(url, feed_entry, feed)
    story = Story.new({:url => url, :submitted_by_member => Member.nt_bot, :status => Story::PENDING, :editorial_priority  => 3, :content_type => "Article"})
    if feed.is_regular_feed?
      story.title = StringHelpers.plain_text(feed_entry.title)
      story.story_date = feed_entry.date_published
    end

      # Journalist names -- ignore author fields for facebook newsfeeds -- these will be set to the poster's name
    story.journalist_names = feed_entry.authors * "," if !feed.is_fb_user_newsfeed? && !feed_entry.authors.blank? 

      # Now, infer other story information
    extra_info = StoryAutoPopulator.populate_story_fields(story, feed_entry, feed.url)

      # Try setting up a story excerpt -- using the feed's description
    if story.excerpt.blank?
      story.excerpt = StringHelpers.plain_text(feed_entry.description) if feed.is_regular_feed? && !feed_entry.description.blank?
      story.debug_excerpt = "rss_feed"
    end

    story.excerpt = "" if story.excerpt.nil?

    return [story, extra_info]
  end

  def self.process_fetched_stories
    @queued_stories = []
    AutoFetchedStory.find(:all, :select => "id").map(&:id).each { |fs_id|
      yield_to_higher_priority_job
      fs = AutoFetchedStory.find(fs_id)
      begin
        s = fs.story

        # If for some reason, the story referenced by fs doesn't exist, get rid of it and move on ...
        if s.nil? 
          fs.destroy
          next
        end

        puts "Processing #{fs_id}; #{s.id} ..."

        if fs.fresh_story
          s.body = fs.body || "" # In case nothing got fetched!
          @logger.info "---- No body for #{fs.id} for story #{s.id} ---" if fs.body.nil?
          orig_excerpt = s.excerpt
          s.excerpt = "" # So that api's can fill up this field
          orig_url = s.url
          feed_story = OpenStruct.new({:title => s.title, :description => fs.description})
          extra_info = StoryAutoPopulator.populate_story_fields(s, feed_story, nil, true)

          s.url_will_change!  # url could have changed in place -- mark it so that, on save, this field is saved by ActiveRecord

          # Restore excerpt from the feed
          if s.excerpt.blank?
            s.excerpt = orig_excerpt
            s.debug_excerpt = "rss_feed"
          end
          s.excerpt = "" if s.excerpt.nil?

          # Check for duplicates once again because once we process the story, the url might have changed!
          story = Story.check_for_duplicates(s.url)
          if story && s.id != story.id
            # selectively merge the two stories without introducing duplicates in tags or story feeds
            story.feed_ids = story.feed_ids | s.feed_ids
            story.add_feed_tags(s.tags.map(&:name))
            s.destroy
            s = story
          end

            ## Add tags & topics to the story, if any were discovered
          if (extra_info && extra_info[:topics])
            s.bot_topics = extra_info[:topics]
          end

          if (extra_info && extra_info[:tags])
            extra_info[:tags].each { |t| s.tag_with(Tag.quote(Tag.curate(t)), :member_id => Member.nt_bot.id) }
          end
        end

          ## Set up default topics from the feeds it belongs to if it has no topic or subject taggings
          ## New policy starting with mynews: Always add default topic tags that editors have set up no matter what the feeds give us.
        s.bot_topics = Tag.find_all_by_slug(s.feeds.collect { |sf| sf.default_topics.blank? ? [] : sf.default_topics.split(",") }.compact.flatten)

          ## Set up default story type if it doesn't already have one by now
        if s.story_type.blank?
          s.feeds.reject { |sf| sf.default_stype.blank? }.each { |sf| s.story_type = sf.default_stype }
        end

          ## Check if we should auto-list this story
        if (s.status == Story::PENDING) && should_autolist_story?(s)
          @logger.info "---- AUTOLISTING STORY #{s.id} ----"
          s.status = Story::QUEUE
          @queued_stories << s
        end

        s.save(false) # no validation!
        s.process_in_background

        # Delete the fetched story entry
        fs.destroy
      rescue Exception => e
        @logger.error "Exception #{e} processing auto-fetched story #{s.id}"
      end
    }

    return @queued_stories
  end
end
