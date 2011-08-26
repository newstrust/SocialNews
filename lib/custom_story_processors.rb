module CustomStoryProcessors
  extend UrlFixupRules

  APP_NAME_SLUG=SocialNewsConfig["app"]["slug"]

  def self.generic_url_fixup(story)
    rv = cleanup_url(story)
    story.authorships.clear if rv && rv[:url_changed] # Gets rid of attribution to the original source if the url has changed!
    rv
  end

## -------- These are custom story processors for non-aggregator sources --------
  def self.washington_post_process_story(story, feed_story)
      # NOTE: If you change this code, also change check_for_duplicates in app/models/story.rb
      # Always add the referrer url -- during partnerships, this lets washington post directly track referrals from the NT site
    story.url = story.url.gsub(/\?.*/, "") + "?referrer=#{APP_NAME_SLUG}"
    return nil
  end

  @@nytimes_url_checks = [
    { :slice => "/world/",      :subject => "World" },
    { :slice => "/national/",   :subject => "U.S." },
    { :slice => "/us/",         :subject => "U.S." },
    { :slice => "/politics/",   :subject => "Politics" },
    { :slice => "/washington/", :subject => "Politics" },
    { :slice => "/business/",   :subject => "Business" },
    { :slice => "/science/",    :subject => "Sci/Tech" },
    { :slice => "/technology/", :subject => "Sci/Tech" },
    { :slice => "/health/",     :subject => "Health" },
    { :slice => "/education/",  :subject => "Education" },
    { :slice => "/arts/",       :subject => "Entertainment",
                                :topic_checks => [
                                  { :slice => "/television/", :topic => "TV" },
                                  { :slice => "/movies/",     :topic => "Movies" },
                                  { :slice => "/music/",      :topic => "Music" },
                                  { :slice => "/books/",      :topic => "Books" },
                                ]
    },
    { :slice => "/sports/",     :subject => "Sports", 
                                :topic_checks => [
                                  { :slice => "football",   :topic => "Football" },
                                  { :slice => "basketball", :topic => "Basketball" },
                                  { :slice => "golf",       :topic => "Golf" },
                                  { :slice => "tennis",     :topic => "Tennis" },
                                ]
    }
  ]

  def self.new_york_times_process_story(story, feed_story)
    url = story.url
    url.gsub!(/\?.*/, "") ## Strip trailing tracker codes from the url

      ## Canonicalize blog urls that end with "/"
    url = "#{url}index.html" if (url =~ %r|.*blogs.*/$|)

      ## Get rid of trailing blog title
    if (url =~ /thecaucus.blogs.nytimes.com/)
      story.title.gsub!(/ - The Caucus - Politics - New York Times Blog$/, "")
    end

      ## Infer the type of story based on the url, where possible.  But, err on the side of caution
    if (story.story_type.nil?)
      if (url =~ /editorials/)
        story.story_type = "editorial"
      elsif ((url =~ /\.blogs\./) || (url =~ /opinion/))
        story.story_type = "opinion"
      end
    end

      ## Infer subjects and topics from the url
    story_topic_tags = []
    story_tags = []
    @@nytimes_url_checks.each { |r1|
      if (url =~ /#{r1[:slice]}/)
        story_tags << r1[:subject]
        if (r1[:topic_checks])
          r1[:topic_checks].each { |r2| story_topic_tags <<  Tag.find_by_name(r2[:topic]) if (url =~ /#{r2[:slice]}/) }
        end
      end
    }

    return { :topics => story_topic_tags, :tags => story_tags, :preserve_title => true}
  end

  def self.huffington_post_process_story(story, feed_story)
      ## NOTE: This does not work correctly!  Example title: "Post-Implosion Politics"
    ## story.title.gsub!(/\s*-[^-]*$/i, "") 
    story.title.gsub!(/^[^:]*:\s*/, "") ## author name
    story.journalist_names.gsub!(%r{http://.*}i, '') if !story.journalist_names.blank? ## get rid of url!
    StoryAutoPopulator.fetch_story_content(story) if story.body.nil?
    if story.body =~ %r|<a\s*href="([^<>"]*?)"[^<>]*>\s*<strong>\s*Read\s+the\s+whole\s+story:\s*<i>[^<>]*</i>\s*</strong>\s*</a>|imx
      new_url = $1
      story.url = new_url
      story.authorships.clear # Gets rid of attribution to Huffington Post
      return { :url_changed => true, :reset_title => true }
    else
      nil
    end
  end

  # Get rid of the print version from the url because these urls break out of the toolbar frame!
  def self.atlantic_monthly_process_story(story, feed_story)
    story.url.gsub!("/print/", "/")
  end

## -------- These are custom story processors for aggregators --------

    # common dreams stories usually come from somewhere else ... fetch the original url!
  def self.commondreams_org_process_story(story, feed_story)
    story.title.gsub!(/\s*\|\s*Common\s*Dreams.*/, '')
    StoryAutoPopulator.fetch_story_content(story) if story.body.nil?
    if story.body =~ %r|Published[^<>]*?<a\shref="(.*?)">|imx
      new_url = $1
        # don't modify if the story is a common dreams original OR if the url is a generic site root link
      if (new_url !~ /commondreams.org/) && (new_url !~ %r|https?://[^/]*/?$|)
        story.url = new_url
        story.authorships = []  # Clear out authorships
        return { :url_changed => true, :preserve_title => true }
      end
    end
    return { :url_changed => false, :preserve_title => true }
  end

    # common dreams stories usually come from somewhere else ... fetch the original url!
  def self.truthout_org_process_story(story, feed_story)
    story.title.gsub!(/^.*t\s*r\s*u\s*t\s*h\s*o\s*u\s*t\s*\|\s*/, '')
    StoryAutoPopulator.fetch_story_content(story) if story.body.nil?
    if story.body =~ %r|<a[^<>]*?href="([^<>]*?)"[^<>]*?class="more_source">|imx
      new_url = $1
        # don't modify if the story is a truthout original OR if the url is a generic site root link
      if (new_url !~ /truthout.org/) && (new_url !~ %r|https?://[^/]*/?$|)
        story.url = new_url
        story.authorships = []  # Clear out authorships
        return { :url_changed => true, :preserve_title => true }
      end
    end
    return { :url_changed => false, :preserve_title => true }
  end

    ## Memeorandum is essentially an aggregator which buries essential info within the description element of the feed
    ## So, we need to parse the description element and extract everything all over again!  Sample description below.
    ##
    ## <p><a href="http://www.memeorandum.com/080521/p138#a080521p138" title="memeorandum permalink">
    ## <img src="http://www.memeorandum.com/img/pml.png" /></a>
    ## Yochi J. Dreazen / <a href="http://online.wsj.com/public/us">Wall Street Journal</a>:<br />
    ## <span><b><a href="http://online.wsj.com/article/SB121133063413809101.html">U.S. Delays Report on Iran Arms</a></b></span>
    ## &nbsp; &mdash;&nbsp; WASHINGTON &mdash; The U.S. military, in a shift, has postponed the release of a report detailing allegations
    ## of Iranian support for Iraqi insurgents, according to people familiar with the matter.&nbsp; &mdash;&nbsp; The military had
    ## initially planned to publicize &hellip;
    ## </p>

  def self.memeorandum_com_process_story(story, feed_story)
    return nil if (feed_story.nil?) ## We don't have sufficient information to process this story!

      ## Extract url and title ... TODO: story quote and author are also available for the taking
    source_name, story.url, story.title = $1, $2, $3 if feed_story.description =~ %r|.*<a\s*href=".*?">([^<>]*?)</a>.*?<a\s*href="(http://.*?)">([^<>]*)</a>.*$|imx

    return { :url_changed => true, :source_name => source_name, :preserve_title => true }
  end

    ## URL: http://news.google.com/news/url?sa=T&ct=us/10-0-0&fd=R&url=http://www.nytimes.com/2008/05/22/world/middleeast/22mideast.html%3Fem%26ex%3D1211601600%26en%3D460aa3bd4ac31170%26ei%3D5087%250A&cid=1214621982&ei=Cfs0SKrZC5T8_AH8m4mkCw&usg=AFrqEzevgINgPHTkw8SrzdKsptCwlCpbeA;
    ## TITLE: Israel Holds Peace Talks With Syria - New York Times

  def self.news_google_com_process_story(story, feed_story)
      ## Fixup url and title
    story.url = $1 if story.url =~ %r{.*url=(.*)&(cid|usg)=.*}
    if !feed_story.nil?
      story.title, source_name = $1, $2 if feed_story.title =~ %r|(.*?)\s*-\s*([^\-]*)$|

      ## TODO: Other info is available for the taking?
      authors, quote = $1, $2 if feed_story.description =~ %r{<table.*?/table>\s*<a.*?<br/?>\s*<font.*?<br/?>\s*<font size='?-1'?>(By.*?\|\s*|By.*?-|By\s+.+?\s+.+?)?([^<>]*).*</font}i
      story.journalist_names = $1 if authors && authors =~ %r{By\s*(.*?)\s*(\||-|,.*)?\s*$}
      story.excerpt = $1 if quote && quote =~ %r{^\s*-?(.*?)\s*$}
    end

    return { :url_changed => true, :reset_title => true, :source_name => source_name }
  end

  @@yahoo_source_prefix_to_slug_map = {
    "ap"                => "associated_press",
    "nm"                => "reuters",
    "cq"                => "congressional_quarterly",
    "afp"               => "afp",
    "csm"               => "christian_science_monitor",
    "time"              => "time",
    "usnews"            => "us_news",
    "politico"          => "politico",
    "huffpost"          => "huffington_post",
    "mcclatchy"         => "mcclatchy",
    "bloomberg"         => "bloomberg",
    "rasmussen"         => "rasmussen_reports",
    "bw"                => "business_week",
    "ft"                => "financial_times",
    "nf"                => "newsfactor",
    "thenation"         => "the_nation",
    "weeklystandard"    => "weekly_standard",
    "realclearpolitics" => "real_clear_politics",
    "livescience"       => "livescience",
    "cnet"              => "cnet_news",
    "zd"                => "pc_magazine",
    "macworld"          => "macworld",
    "pcworld"           => "pcworld",
    "hsn"               => "healthday",
    "infoworld"         => "infoworld",
    "eonline"           => "eonline",
    "ap_travel"         => "associated_press",
  }

  def self.common_yahoo_com_processor(story, feed_story, domain_story_url_prefix)
      # Strip the title of trailer txt
    story.title.gsub!(/\s*[-:]\s*Yahoo!?\s+.*$/, '')

      # Strip the url of any tracking parameters
    story.url.gsub!(/;_ylt=(\w|\.)*/, '')

      # Try to find the original source this article is from by examining the url
    url    = story.url
    slug   = @@yahoo_source_prefix_to_slug_map[$1] if url =~ %r|#{domain_story_url_prefix}/(.*?)/|
    source = Source.find_by_slug(slug) if slug

      # Overwrite authorships (gets rid of the yahoo news attribution)
    if source
      story.authorships.clear
      story.authorships = [Authorship.new(:source => source)] 
    end

    return { :preserve_title => true }
  end

  def self.news_yahoo_com_process_story(story, feed_story)
    common_yahoo_com_processor(story, feed_story, "yahoo.com/s")
  end

  def self.tech_yahoo_com_process_story(story, feed_story)
    common_yahoo_com_processor(story, feed_story, "tech.yahoo.com/news")
  end

  def self.google_com_process_story(story, feed_story)
    if (story.url =~ %r|google.com/hostednews/ap/|)
      source = Source.find_by_slug("associated_press")
    elsif (story.url =~ %r|google.com/hostednews/afp/|)
      source = Source.find_by_slug("afp")
    end

      # Overwrite authorships (gets rid of the google news attribution)
    if source
      story.authorships.clear
      story.authorships = [Authorship.new(:source => source)] 
    end

    return nil
  end

# SSS FIXME: Need a mechanism that works even in normal story lookups 
  def self.digg_com_process_story(story, feed_story)
    metadata = MetadataFetcher.get_api_metadata(story, :digg) if feed_story
    if (metadata.blank? || metadata[:empty])
      nil
    else
      story.url     = metadata[:link]
      story.excerpt = metadata[:desc] if !metadata[:desc].blank?
      story.title   = metadata[:title] if !metadata[:title].blank?
      { :url_changed => true, :tags => metadata[:tags] }
    end
  end
end
