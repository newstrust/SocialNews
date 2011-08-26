require 'open-uri'
require 'net/http'
require 'feed-normalizer'

module FeedHelpers
  @@timeout_period = 15 ## Default timeout
  @@max_retries    = 5  ## Default number of attempts to fetch a url before giving up!

  def self.is_rss_candidate(href)
    href =~ %r{\.xml|\.rss|\.atom|\.rdf|/rss|rss/|feeds?\.|feeds?/|feedproxy\.}
  end

  def self.get_rssfeed_candidates(url, options = {})
    url_pattern    = options[:url_pattern]
    only_from_head = options[:only_from_head]
    only_one       = options[:only_one]

      # Add trailing / if the url is just a domain name without a trailing slash
    url += "/" if (url =~ %r|^http://[^/]*$|) 
    uri = URI.parse(url)

      # Follow redirects as necessary, while setting cookies! (ex: NY Times)
      # For most sites that don't do the redirect dance, you will get the title in the first try
    num_redirects = 0
    resp   = nil
    cookie = nil
    while (num_redirects < @@max_retries)
      resp = Net::HTTP.start(uri.host, uri.port) { |http|
        remote_resource = uri.query ? (uri.path + "?" + uri.query) : uri.path
          # Some sites don't want to return you HTML if you are not a "normal browser"
          # So, fool them by passing a "normal browser" User-Agent string!
          # For a particular humorous post about the uselessness of these user agent strings, check
          #    http://www.webaim.org/blog/user-agent-string-history/
        headers = { "User-Agent" => "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9b5) Gecko/2008050509 Firefox/3.0b5" }

          # Set cookie that you are given -- essential to fool the server to think you are a normal browser
        headers.merge!({ "Cookie" => cookie }) if cookie
        http.request(Net::HTTP::Get.new(remote_resource, headers))
      }

        # Follow redirects till you get a normal OK
      case resp
      when Net::HTTPMovedPermanently then
        uri = URI.parse(resp['location'])
        cookie = resp['set-cookie']
        num_redirects += 1
      when Net::HTTPFound then
        uri = URI.parse(resp['location'])
        ret_cookies = resp.get_fields('set-cookie')
        cookie = ret_cookies.inject("") { |s,c| s + c.split("\; ")[0] + "\; " } if ret_cookies
        num_redirects += 1
      when Net::HTTPSuccess   then
        break
      end
    end

    rss_candidates = Hash.new
    body = resp.body
      # Title could have ' or " characters depending on what quote characters are used to enclose it.
      # <link rel="alternate" href="http://twitter.com/statuses/user_timeline/23625465.rss" title="p2journalism's Updates" type="application/rss+xml" />
    body.gsub(%r{(<link[^>]*?type=["']application/rss\+xml["']\s*[^>]*?/>)}imx) { 
      line = $1
      url    = $1 if line =~ /href=['"]([^"']*)['"]/
      target = $2 if line =~ /title=(['"])(.*?)\1/
      next if (url_pattern && url !~ /#{url_pattern}/)
      rss_candidates[url] = target 

        # If we want only one link, return after we find one!
      break if only_one
    }

      ## Fetch other rss links from the body if we haven't been asked to find only from the html head tag
    if (!only_from_head && (rss_candidates.blank? || !only_one))
      baseHref = $1 if url =~ %r{(http://.*?)(\/[^/]*)?(\?.*)?$}i
      baseHref += "/" if baseHref !~ %r{/$}

      body.gsub(%r{<a.*?href=(['|"]?)([^ "<>]+)\1.*?>(.+?)</a>}imx) {
        next if (url_pattern && $2 !~ /#{url_pattern}/)

        href   = $2 
        target = $3.gsub(/<.*?>/, '')
        if (href !~ %r{https?://})
          href = (baseHref + href).gsub(%r{//}, '/').sub(":/", "://")
        end
        if is_rss_candidate(href)
          rss_candidates[href] = target 

            # If we want only one link, return after we find one!
          break if only_one
        end
        ""
      }
    end

    retval = { :rss_feeds => rss_candidates }

    if (options[:get_meta_description])
      desc_line = $1 if body =~ %r{(<meta\s*[^>]*?name=["']description['"][^>]*?/>)}
      retval[:desc] = $2 if desc_line && (desc_line =~ %r{content=(['"])(.*?)\1})
    end

    retval
  end

  def self.update_feed_attributes(fp)
    url, home_page, name, desc = fp[:url], fp[:home_page], fp[:name], fp[:desc]

    if !home_page.blank? && (url.blank? || name.blank? || desc.blank?)
      fc   = get_rssfeed_candidates(home_page, {:only_from_head => true, :only_one => true, :get_meta_description => true})
      url  = fc[:rss_feeds].keys.first if url.blank? && !fc[:rss_feeds].blank?
      desc = fc[:desc] if desc.blank?
      name = fc[:rss_feeds][url] if name.blank? && !fc[:rss_feeds].blank?
    elsif url.blank? && home_page.blank?
      raise "One of url or home_page should not be blank!"
    end

    if !url.blank? && url !~ /^http:/
      domain = $1 if (url =~ %r|^(http://[^/]*).*$|) 
      url = "#{domain}#{url}"
    end

    feed = nil
    if desc.blank? && !url.blank?
      begin 
        feed = FeedNormalizer::FeedNormalizer.parse open(url) 
        desc = feed.description if feed 
      rescue Exception => e 
      end
    end

    if home_page.blank?
      begin 
        feed = FeedNormalizer::FeedNormalizer.parse open(url) if !feed
        home_page = feed.urls[0] if feed
      rescue Exception => e 
      end
    end

    if name.blank?
      begin 
        feed = FeedNormalizer::FeedNormalizer.parse open(url) if !feed
        name = feed.title if feed
      rescue Exception => e 
      end
    end

    { :url => url, :home_page => home_page, :name => name, :desc => desc }
  end

  def self.import_feed_descriptions(f)
    File.open(f).each_line { |line|
      fields     = line.split("\t")
      name       = fields[1]
      subtitle   = fields[2]
      url        = fields[3].gsub(/feed:/, "http:")
      home_page  = fields[4]
      keep_hide  = fields[12]

      next if keep_hide =~ /^H.*$/i

      begin 
        fp = update_feed_attributes :url => url, :home_page => home_page, :desc => desc
        puts "Description for feed #{name} - #{subtitle}: #{fp[:desc] || ''}"
      rescue Exception => e
      end
    }
  end

  def self.parse_feed_file(f)
    File.open(f).each_line { |line|
      fields     = line.split("\t")
      list_bias  = fields[0].gsub(/%/, '').to_i
      name       = fields[1]
      subtitle   = fields[2]
      url        = fields[3].gsub(/feed:/, "http:")
      home_page  = fields[4]
      feed_type  = fields[5]
      feed_group = fields[6]
      src_prof   = fields[7]
      mem_prof   = fields[8]
      topics     = fields[10]
      stype      = fields[11]
      keep_hide  = fields[12]
      desc       = fields[25]

      puts "Processing line for #{name}"

      begin
        fp = update_feed_attributes :url => url, :home_page => home_page, :desc => desc
        url, home_page, desc = fp[:url], fp[:home_page], fp[:desc]
        next if url.blank?
      rescue Exception => e
        puts "ERROR: #{e}. Skipping #{line}"  
        next
      end

        # Process this after we have a url!
      if keep_hide =~ /^H.*$/i
        existing_feed = Feed.find_by_url(url)
        if existing_feed
          existing_feed.update_attribute(:auto_fetch, false)
          puts "... Stopping autofetch of this feed since we have a hide request: #{keep_hide}"
        else
          puts "... ignoring this line since we have a hide request: #{keep_hide}"
        end
        next
      end

      if !topics.blank?
          ## Editors are entering topic/subject names rather than slugs
        topics = topics.split(",").collect { |tn| begin; Topic.find_by_name(tn).slug; rescue Exception => e; puts e; nil; end }.join(",")
      end

      if !src_prof.blank?
        src_prof = Source.find_by_name(src_prof)
        src_prof_id = src_prof.id if src_prof
      end

      if !mem_prof.blank?
        mem_prof = Member.find_by_name(mem_prof)
        mem_prof_id = mem_prof.id if mem_prof
      end

      existing_feed = Feed.find_by_url(url)
      if (existing_feed.nil?)
        begin 
          Feed.create({:url => url, 
                       :name => name, 
                       :subtitle => subtitle,
                       :imported_desc => desc, 
                       :home_page => home_page, 
                       :default_topics => topics, 
                       :auto_fetch => true,
                       :feed_level => list_bias,
                       :feed_type => feed_type,
                       :feed_group => feed_group,
                       :source_profile_id => src_prof_id,
                       :member_profile_id => mem_prof_id,
                       :default_stype => stype })

        rescue Exception => e
          puts "Exception creating feed for entry #{line}; #{e}"
        end
      else
          # Update info of existing feed
        puts "Feed already exists .. updating info!"
        existing_feed.update_attributes({
                       :name => name, 
                       :subtitle => subtitle,
                       :imported_desc => desc, 
                       :home_page => home_page, 
                       :default_topics => topics, 
                       :feed_level => list_bias,
                       :feed_type => feed_type,
                       :feed_group => feed_group,
                       :source_profile_id => src_prof_id,
                       :member_profile_id => mem_prof_id,
                       :default_stype => stype })
      end
    }
  end

  def self.fetch_favicon_url(f)
    img = nil
    if (f.is_twitter_feed? && f.home_page)
      url, content = NetHelpers.fetch_content(f.home_page)
      # Ex: <a href="/account/profile_image/sivavaid?hreflang=en"><img alt="" border="0" height="73" id="profile-image" src="http://a3.twimg.com/profile_images/379295215/P1010025_bigger.jpg" valign="middle" width="73" /></a>
      img = $1 if content =~ %r|id="profile-image"\s*src="([^'"<>]*)?"|imx
      puts "ICON for #{f.name} - #{f.subtitle} is #{img}" if img
    end
    return img
  end

#  def self.doit
#    Feed.find(:all).each { |f|
#      begin
#        if (!f.home_page.blank?)
#          fc = get_rssfeed_candidates(f.home_page, {:only_from_head => true, :only_one => true, :get_meta_description => true})
#          puts "NAME: #{f.name}; URL: #{f.url}; DESC: #{fc[:desc]}"
#        end
#      rescue Exception => e
#        puts "Got exception #{e}"
#      end
#    }
#  end
end
