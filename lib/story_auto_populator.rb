require 'open-uri'
require 'hpricot'
if !defined?(MetadataFetcher)
  require 'metadata_fetcher'
end

class StoryAutoPopulator
  class << self
    include SapHelpers
  end

  @logger = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}_story_auto_populator.log")
  @logger.formatter = RailsFormatter.new

  def self.logger; @logger; end

      ## Domains that reject our toolbar (or don't work well without 3rd party cookies enabled in the browser)
  FRAMEBUSTER_DOMAINS = [ "nytimes.com", "npr.org", "newyorker.com", "vanityfair.com", "vimeo.com", "examiner.com", "business-strategy-innovation.com" ]

      ## Sample urls with varied date formats
      #
      ## http://www.examiner.com/blogs/tapscotts_copy_desk/2008/2/6/Now-we-see-if-McCain-really-wants-conservatives
      ## http://thinkprogress.org/2008/01/28/embargoed-state-of-the-union-text-2/
      ## http://www.csmonitor.com/2008/0104/p02s01-usgn.html
      ## http://www.lasvegassun.com/news/2008/feb/06/reid-renewables-shorted-bush-budget/
      ## http://www.voanews.com/english/2007-05-08-voa65.cfm
      ## http://www.cnn.com/2008/CRIME/01/01/db.cooper.ap/index.html
      ## http://www.cnn.com/2007/WORLD/asiapcf/01/02/australia.aborigine.reut/index.html
      ## http://blog.cleveland.com/openers/2008/01/kucinich_drops_presidential_bi.html
      ## http://www.heraldtribune.com/apps/pbcs.dll/article?AID=/20070102/COLUMNIST17/701020373
      ## http://news.enquirer.com/apps/pbcs.dll/article?AID=/20070219/EDIT02/702190317/1090
      ## http://arstechnica.com/news.ars/post/20070221-8895.html
      ## http://www.columbiatribune.com/2007/Aug/20070808Comm002.asp 
      ## http://www.businessweek.com/print/technology/content/jan2007/tc20070122_842933.htm

  TODAY_FORMATS = [ 
      "%Y%m%d",       ## 20080503
      "/%Y/%b/%d",    ## /2008/May/03
      "/%Y/%m/%d",    ## /2008/05/03
      "/%Y/*%m/*%d",  ## /2008/5/3  -- (* will be fixed by date_format_hack)
      "/%Y-%m-%d",    ## /2008-05-03
      "/%Y/%m%d",     ## /2008/0523
  ]

      ## Order of the regexps is significant.  Do not change
  URL_DATE_REGEXPS = [
      "cnn.com/(\\d\\d\\d\\d)/.*?/(\\d\\d)/(\\d\\d)/",            ## cnn.com/2007/WORLD/asiapcf/01/02/
      "[^\\d](\\d\\d\\d\\d)[^\\d](\\d\\d?)[^\\d](\\d\\d?)[^\\d]", ## 2008/5/3/, 2005/05/03, 2008-05-03
      "/(\\d\\d\\d\\d)/(\\d\\d)(\\d\\d)/",                        ## /2008/0503/
      "[^\\d](\\d\\d\\d\\d)(\\d\\d)(\\d\\d)[^\\d]",               ## 20080503
      "/(\\d\\d\\d\\d)/(\\w*)/(\\d\\d?)/",                        ## /2008/May/03/
  ]

      ## Wire services and regexps to find references to them in a story
  WIRE_SERVICES = {
    :associated_press           => { :name => "Associated\s+Press", :abbrev => "AP" },
    :reuters                    => { :name => "Reuters" },
    :united_press_international => { :name => "United\s+Press\s+International", :abbrev => "UPI" }
  }


      ## TODO: This code should be in some other file / helper?
  MONTHS = [ 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec' ]
  def self.get_month_number_from_name(m)
    MONTHS.each_index { |i|
      return i+1 if (m =~ /^#{MONTHS[i]}/i)
    }
    return -1
  end

  @@timeout_period = 30
  @@max_retries    = 5  ## Default number of attempts to fetch a url before giving up!

  def self.set_http_timeout(n)
    @@timeout_period = n
  end

  def self.set_max_retries(n)
    @@max_retries = n
  end

    ## Ruby's time formatting strings don't have a way of outputting days and months without a leading zero
    ## This code is a hack courtesy http://www.nullislove.com/2007/05/16/time-for-strftime/
    ## This method expects a "*" to be prefaced before the days and months that need replacement
  def self.date_format_hack(str)
    str.gsub('*0', '').gsub('*', '')
  end

    # Since the story won't have been saved, we need to fetch the source using authorships
  def self.non_wire_service_story_source(s)
    return nil if s.authorships.empty?
    s.authorships.to_ary.find { |a| WIRE_SERVICES[a.source.slug].nil? }.source
  end

  def self.get_target_url(url)
    NetHelpers.get_target_url(url)
  rescue Exception => e
    @logger.error e
    return url
  end

  def self.set_story_source(story)
    source      = nil
    full_domain = NetHelpers.get_url_domain(story.url)

      ## Don't bother if the domain is an aggregator domain -- this will be fixed in
      ## a second pass after custom processing ...
    return if is_aggregator_domain?(full_domain)

        ## Progressively strip off components of the domain and try to fetch the source ... 
        ##
        ## - For many urls, since we have already stripped off the "www.",
        ##   this will succeed in the first try, or fail in the 2nd
        ## - For urls like thecaucus.blogs.nytimes.com, it will succeed in the 3rd try
    fallback_source = nil
    domain_parts = full_domain.split("\.")
    n            = domain_parts.length
    # SSS: n-2 because we dont want to match TLD's (.net, .com, .org, etc!)
    (0 .. (n-2)).each { |i|
      domain = domain_parts[i..n].join(".")

        ## Find all sources matching the domain and check which of those sources
        ## are matched by the story url
      sources = Source.find_all_by_domain(domain) || []

      if sources.length > 1
        source = sources.find { |s| story.url =~ /#{s.section}/i if s.section }
          ## This is the default source which we will fallback to if we don't find a matching section
          ## Set it just once
        fallback_source = sources.first if fallback_source.nil?
      else
        source = sources.first
      end

      break if !source.nil?
    }

      ## Pick the fallback source in case we don't find a matching source section within the main site
    source = fallback_source if source.nil?

    ## puts "story url is #{story.url}"
    ## puts "source is #{source.name}" if (!source.nil?)

      ## Avoid dupe sources!
    story.authorships << Authorship.new(:source => source) if source && !story.authorships.to_ary.find { |a| a.source.id == source.id }
  end

  def self.build_new_source(story, extra_info)
    story_domain = NetHelpers.get_url_domain(story.url)
    return nil if is_aggregator_domain?(story_domain)

      # check if we get source name in extra_info -- default name is the story_domain
    source_name = (extra_info && extra_info[:source_name]) ? extra_info[:source_name] : story_domain
    source = Source.build_new_source(source_name, story_domain)

      # Add to the database!
    source.save

    return source
  end

  def self.clean_story_title(story)
      ## Canonicalize the story title by stripping excess white space
    story.title.gsub!(/\s+/, ' ')
    story.title.strip!

      ## Strip HTML tags
    story.title.gsub!(%r|<.*?>|, "")

      ## Strip domain name from title, if present 
    domain = NetHelpers.get_url_domain(story.url)
    story.title.gsub!(/^#{domain}\s*[|\-:]?\s*/i, "")
    story.title.gsub!(/\s*[|\-:]?\s*#{domain}\s*[|\-:]?$/i, "")

    source = non_wire_service_story_source(story)
    if (source && source.name)
        ## Strip source name from title, if present
      story.title.gsub!(/^(the\s*)?#{source.name}\s*[|\-:]?\s*/i, "")
      story.title.gsub!(/\s*[|\-:]?\s*(the\s*)?#{source.name}\s*[|\-:]?$/i, "")
    end

      ## unescape XML escapes in the title
    story.title = Hpricot.uxs(story.title.gsub(/&apos;/, "'")) ## Hpricot is replacing &apos; with ? ... BUG?
  end

  def self.custom_process_story(story, feed_story, feed_url)
        ## 1. If the story already has a source, push it through a source-specific
        ##    story processor, if one exists
    source = non_wire_service_story_source(story)
    if (source && source.slug)
      custom_processor = source.slug + "_process_story"
      if (CustomStoryProcessors.respond_to?(custom_processor))
        return CustomStoryProcessors.send(custom_processor, story, feed_story)
      end
    end

        ## 2. If we couldn't process the story in the previous step, see if we have
        ##    a domain-specific story processor.  Multi-source domains (ABC News, NPR, etc.)
        ##    and aggregators that use proxy urls (Ex: Memeorandum, Google News) would
        ##    use this route to fix up stories.
    custom_processor = NetHelpers.get_url_domain(story.url).gsub(/\./, '_') + "_process_story"
    if (CustomStoryProcessors.respond_to?(custom_processor))
      return CustomStoryProcessors.send(custom_processor, story, feed_story)
    end

        ## 3. If we couldn't find either a source-specific story processor OR a domain-specific 
        ##    story processor, check if there is a feed-specific story processor.  Aggregators
        ##    that don't use proxy urls for their stories would use this route to fix up stories.
    if (!feed_url.nil?)
      custom_processor = NetHelpers.get_url_domain(feed_url).gsub(/\./, '_') + "_process_story"
      if (CustomStoryProcessors.respond_to?(custom_processor))
        return CustomStoryProcessors.send(custom_processor, story, feed_story)
      end
    end

        ## 4. Last attempt to process the story -- push it through a generic url fixup method
        ##    This is likely going to be the common-case for most submitted stories
    CustomStoryProcessors.generic_url_fixup(story)
  rescue Exception => e
    @logger.error "While custom processing story #{story.url}, got an error: #{e.message}"
    nil
  end

  def self.set_story_format(story)
    source = non_wire_service_story_source(story)
      # We are setting the story type ONLY if we are sure of what it is!
    #story.story_type = "opinion" if (is_blog_domain?(NetHelpers.get_url_domain(story.url)) || (source && source.primary_medium =~ /blog/i))
    story.story_type = "opinion" if (source && source.primary_medium =~ /blog/i)
  end

  def self.set_story_date(story)
      ## No need to do anything if we have a date already
    return if !story.story_date.nil?

    now = Time.now
    url = story.url

      ## 1. Do the easy thing first!  Most stories will be submitted the day they are published.
      ## If we get a hit for today's date, we will be done, and this reduces guessing and errors
    TODAY_FORMATS.each { |f|
      if (url =~ %r|#{date_format_hack(now.strftime(f))}|i)
        story.story_date = now
        break
      end
    }

      ## 2. Try to parse the url according to various regexps
    if (story.story_date.nil?)
      URL_DATE_REGEXPS.each { |dre|
        if (url =~ %r|#{dre}|i)
          y, m, d = $1, $2, $3
          #puts "regexp: #{dre}; y- #{y}, m- #{m}, d- #{d}"
          m = get_month_number_from_name(m) if (m =~ /[a-zA-Z]/)
            # Make sure that the match is not a spurious one!
          if (y.to_i <= now.year && m.to_i > 0 && m.to_i < 13 && d.to_i < 32 && d.to_i > 0)
            story.story_date = Time.local(y, m, d, now.hour, now.min, now.sec)
            break
          end
        end
      }
    end

      ## 3. Default: Set to today's date
    if (story.story_date.nil?)
      story.story_date = now
    end
  rescue Exception => e
    @logger.error "While setting date for story with url #{story.url}, got an error: #{e.message}"
    story.story_date = now
  end

  def self.fetch_story_content(story)
    # Check if the story being submitted is a story that is a toolbar url
    # In that situation, simply bail!
    domain = NetHelpers.get_url_domain(story.url)
    return if (domain =~ /#{APP_DEFAULT_URL_OPTIONS[:host]}/)  ## there might be a port .. ignoring the port

    story.url, story.body = NetHelpers.fetch_content(story.url)
  rescue Exception => e
    @logger.error "While fetching story content for #{story.url}, got an error: #{e.message}"
  end

  def self.set_story_title(story)
    fetch_story_content(story) if !story.body
    story.title = $1 if story.body =~ %r|<title>(.*?)</title>|imx
  end

  def self.attribute_to_wire_services(story)
    fetch_story_content(story) if !story.body
    return if !story.body

      # Remove all javascript since hpricot wont remove this!
    story.body.gsub!(%r|<script.*?</script.*?>|imx, "")

      # Remove everthing till the title
      # REASON: In the heuristic below, we try to find a match for a wire service name
      # in close # proximity of the story title/headline.  Hence it is important to
      # remove the title tag because we want the title tag text to match there!
    story.body.gsub!(%r|^.*</title>|imx, "")

      # Get rid of any wire service image attributions!
    WIRE_SERVICES.keys.find { |k|
      name   = WIRE_SERVICES[k][:name]
      abbrev = WIRE_SERVICES[k][:abbrev]
      no_tag_re    = "[^<>]*"
      br_re        = "\\s*<br\\s*\/?>"
      close_tag_re = "\\s*<\/#{no_tag_re}>"
      open_tag_re  = "\\s*<#{no_tag_re}>"

        # Protect copyright notices from regexp below!
      story.body.gsub!(/(Copyright(\s|\w)+#{name})/, "<<<img></img><p></p>>>" + '\1')

        # IMG tag + [zero or more (closing tags, <br/>s) + text + [one or more opening tags + text]] + wire service name 
        # Substitute this ONLY once (sub, not gsub)
      if abbrev.blank?
        story.body.sub!(/(<img#{no_tag_re}>(#{close_tag_re}|#{br_re})*#{no_tag_re}(#{open_tag_re}+#{no_tag_re})?)#{name}/i, '\1')
      else
        story.body.sub!(/(<img#{no_tag_re}>(#{close_tag_re}|#{br_re})*#{no_tag_re}(#{open_tag_re}+#{no_tag_re})?)(#{name}|\s#{abbrev}\s)/i, '\1')
      end

        # Remove copyright notice protection
      story.body.gsub!(/<<<img><\/img><p><\/p>>>/, '')
    }

      # Extract just the text
    body_text = Hpricot(story.body).inner_text.gsub!(/\s+/, ' ')
    WIRE_SERVICES.keys.find { |k|
      name   = WIRE_SERVICES[k][:name]
      abbrev = WIRE_SERVICES[k][:abbrev]
      posn   = (body_text =~ /#{name}/)
      posn   = (body_text =~ /\(#{abbrev}\)/) if (!posn && abbrev)
      posn   = (body_text =~ /\s+#{abbrev}\s+/) if (!posn && abbrev)

        # Attempt a partial match of the title -- 25 characters is arbitrary!
        # This is because the text within the <title> tag and the actual title
        # displayed within the body might not be an exact match
      max_match_length = (story.title.length < 25 ? story.title.length: 25)
      title_match = (body_text =~ /#{story.title[0..max_match_length].gsub("\?", '\\?')}/)

        # 1. If we hit the name of the wire service within 100 characters of the title end, we consider this a hit! 
        #   (100 characters is arbitrary!)
        # 2. If we can't match the title of the story, or if it is beyond 100 characters from the title, .. accept if 
        #   the hit is within 10% of the article beginning (10% is arbitrary!)
        # 3. But, sometimes copyright notices tend to be at the bottom ... accept them
        #
        # In both 1. and 2. check if the attribution is right after an img tag -- in that case,
        # the attribution might be for the image rather than the article!
      match = false
      if (posn && title_match && ((posn - title_match) < story.title.length + 100))
        match = true
      elsif (posn && (posn < 0.10 * body_text.length))
        match = true
      elsif (body_text =~ /Copyright(\s|\w)+#{name}/)
        match = true
      end

        # We got a match! Add the wire service as the source of the article
      if (match)
          # If the byline is attributed to the wire service as well as the source, keep both of them.
          # If not, only the wire service!
          # 50 chars is arbitrary 
          # I presume most author names along with spaces and 'By', 'and', and anythign else will fit within 50 chars 
        n = (body_text =~ /\s+By.*?and.*?#{name}\s+/im)
        match_data = $~
        story.authorships.clear if (!n || ((posn - n) > 50) || match_data.string.length > (50 + name.length))
        story.authorships << Authorship.new(:source => Source.find_by_slug(k.to_s))

        true
      else
        false
      end
    }
  rescue Exception => e
    @logger.error "Exception #{e} trying to find wire service attribution for #{story.url}; #{e.backtrace.inspect}"
  end

  def self.update_story_metadata_from_apis(story, preserve_title=false)
      ## Fetch title
    if !preserve_title || story.title.blank?
      title = MetadataFetcher.get_story_title(story)
      story.title = title if !title.blank?
    end

    story.story_date = MetadataFetcher.get_story_date(story)

      ## Journalist names
    if story.journalist_names.blank?
       authors = MetadataFetcher.get_story_authors(story)
       story.journalist_names = authors if !authors.blank?
    end

      ## Fetch story excerpt
    if story.excerpt.blank?
      excerpt = MetadataFetcher.get_story_excerpt(story)
      story.excerpt = StringHelpers.plain_text(excerpt) if !excerpt.blank?
    end

      ## Fetch tags
    tags = MetadataFetcher.get_story_tags(story)
    topic_tags = tags.collect { |t| Tag.find_by_name(t, :conditions => "tag_type IS NOT NULL") }.compact

      # For now, this is the only info being returned!
    { :topics => topic_tags }
  end

  def self.populate_story_fields(story, feed_story = nil, feed_url = nil, update_metadata = false)
      # Ignore images, movies, pdfs, word files, and ads
    if ad_image_or_ignoreable?(story.url)
      set_story_date(story)
      return 
    end

      # Check if the story being submitted is a toolbar url
      # In that situation, recover the target url
    if (story.url =~ %r|#{APP_DEFAULT_URL_OPTIONS[:host]}(\:\d+)?/stories/(\d+)(/.*)?$|)
      begin
        story_id = $2
        if story_id
          s = Story.find(story_id) 
          story.url = s.url 
        end
      rescue
      end

      # Don't attempt to do anything more!
      return
    end

      # Get rid of white space
    story.url.strip!
    orig_url = story.url

    if feed_story
        ## 0. Query Tweetmeme's API before the url is canonicalized.
        ## We are more likely to get a hit if we use the original shortened url from the twitter stream
      MetadataFetcher.get_api_metadata(story, :tweetmeme, {:refresh => false, :store_if_empty => false})

        ## Handle Daylife specially.  Daylife doesn't use canonical urls.  So, first try with the original url.
        ## If we don't get a hit, dont store the result so that we query daylife once more later with the new url.
        ## But, since twitter short urls are always going to fail in daylife, dont bother with the initial query.
        ## Wait till the url resolves in those cases.
      if feed_url.nil? || (feed_url =~ /twitter.com/).nil? || (feed_url =~ /facebook.com/).nil?
        MetadataFetcher.get_api_metadata(story, :daylife, {:refresh => false, :store_if_empty => false})
      end
    end

      ## 1. unescape URL escapes, follow proxies, and get rid of trailing white-space, if any
    story.url = get_target_url(CGI.unescape(story.url)).strip

      # Record the original url as an alternate url so that future queries by that url will retrieve this story!
      # FIXME: This info is lost when we are using the submit form
    story.urls << StoryUrl.new(:url => orig_url) if (story.url != orig_url)
    orig_url = story.url

      ## 2. Fetch story content for the story -- this also sets up a canonical url in certain cases
    fetch_story_content(story) if story.body.nil?

      ## 3. Set story title
    set_story_title(story) if story.title.blank?

      ## 4. Initial attempt at setting source id for the story
    set_story_source(story)

      ## 5. Push the story through a source-specific custom story processor
      ## This might update the story and modify the url & title for the story
      ## (for aggregators like Memeorandum & Google News), and return
      ## any other additional story info that can be inferred.
    extra_info = custom_process_story(story, feed_story, feed_url)

      # Record the original url as an alternate url so that future queries by that url will retrieve this story!
      # FIXME: This info is lost when we are using the submit form
    story.urls << StoryUrl.new(:url => orig_url) if story.url != orig_url
    orig_url = story.url

      ## 6. While the url for the story continues to change, try to eliminate proxies and set the story source from the url again!
      ## For example, after a daylife / digg url / fairspin url (or from other aggregators) is processed, you will get the target url
      ## which can be yet another feed-based proxy, and so on ... 
      ##
      ## But, dont spin for ever -- three times lucky!

    count = 0
    while (count < 3) && (extra_info && extra_info[:url_changed])
      count += 1
      old_ei = extra_info
      story.body = nil

      story.url = get_target_url(CGI.unescape(story.url)).strip
      set_story_source(story)
      extra_info = custom_process_story(story, nil, nil)

        # Combine info from multiple passes 
      extra_info ||= {}
      extra_info[:reset_title]    ||= old_ei[:reset_title]
      extra_info[:preserve_title] ||= old_ei[:preserve_title]
      [:topics,:tags].each { |k| extra_info[k] = (extra_info[k] || []) + old_ei[k] if !old_ei[k].blank? }

        # Record the original url as an alternate url so that future queries by that url will retrieve this story!
        # FIXME: This info is lost when we are using the submit form
      story.urls << StoryUrl.new(:url => orig_url) if (story.url != orig_url)
    end

      ## 7. If we still don't have a source, build a source object
    if (story.authorships.empty? && !is_aggregator_domain?(NetHelpers.get_url_domain(story.url)))
      story.authorships << Authorship.new(:source => build_new_source(story, extra_info))
    end

      ## 8. Infer story format, where possible, but don't overwrite any inferences made by the custom story processors!
    set_story_format(story) if story.story_type.nil?

      ## 9. If we are fetching a RSS feed, get all the info you can get by querying apis and update story fields
    if feed_story || update_metadata
      MetadataFetcher.query_all_apis(story)
      extra_info ||= {}
      api_info = update_story_metadata_from_apis(story, extra_info[:preserve_title])
      [:topics,:tags].each { |k| extra_info[k] = (extra_info[k] || []) + api_info[k] if !api_info[k].blank? }
    end

      # 10. Infer story date, where possible
    set_story_date(story) if story.story_date.nil?

      # 11. Reset story title, if necessary
    if (extra_info && extra_info[:reset_title])
      story.title = nil

        ## Don't mess around with the url at this point -- since set_story_title updates the url 
        ## to whatever we get from the remote server, copy orig url and reset it.
      orig_url = story.url
      set_story_title(story)
      story.url = orig_url
    end

      # Make sure we are not storing the story's final url as an alternate (can happen in the midst of all the url fixups)
    story.urls.reject! { |alt| alt.url == story.url }

      # 12. Clean up story title as well as you can
    clean_story_title(story) if story.title

    # SSS: As per Fab's request on Jun 30, 2011, turning this off
    #  # 13. Look for wire services attribution
    # attribute_to_wire_services(story)

      # Clear out the story body -- we no longer need it!
    story.body = nil

      # Return whatever additional info we've gathered
    return extra_info
  end
end
