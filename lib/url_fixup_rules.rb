module UrlFixupRules
  @@url_fixup_rules = {
        # http://www.sfgate.com/cgi-bin/article.cgi?f=/c/a/2008/05/28/ED2K10U856.DTL&feed=rss.opinion
    "sfgate.com"         => { :regexp => "(&feed=[^&]*)|(&type=[^&]*)", :repl => "", :url_changed => false },
        # http://www.marketwatch.com/news/story/mishkin-resigning-fed-return-academia/story.aspx?guid={B82EF056-B712-42C7-BAF8-F02886D12DC4}&dist=msr_7
    "marketwatch.com"    => { :regexp => "&dist=[^&]*", :repl => "", :url_changed => false },
        # http://www.bloomberg.com/apps/news?pid=20601087&sid=aDmOLUs6VCz8&refer=home
    "bloomberg.com"      => { :regexp => "&refer=[^&]*", :repl => "", :url_changed => false },
        # http://www.cbsnews.com/stories/2008/03/06/60minutes/main3914719.shtml?source=RSSattr=60Minutes_3914719
        # http://www.cbsnews.com/video/watch/?id=4493093n?source=mostpop_video
    "cbsnews.com"        => { :regexp => "\\?source=[^?&]*", :repl => "", :url_changed => false },
        # http://news.newamericamedia.org/news/view_article.html?article_id=3172f2965d1a32817bff097afa501763&from=rss
    "news.newamericamedia.org" => { :regexp => "&from=[^&]*", :repl => "", :url_changed => false },
        # http://www.cnn.com/2008/WORLD/europe/05/28/uk.cluster.bomb/?iref=mpstoryview
        # http://www.cnn.com/video/?/video/bestoftv/2009/06/14/gps.amanpour.from.iran.cnn
    "cnn.com"            => { :regexp => "\\?[^/]*$", :repl => "", :url_changed => false },
        # http://wsj.com/article/SB121266426291048185.html?mod=googlenews_wsj
        # http://wsj.com/article/SB121266426291048185.html#mod=googlenews_wsj
    "wsj.com"            => { :regexp => "(\\?|#).*$", :repl => "", :url_changed => false },
        # http://online.wsj.com/article/SB121266426291048185.html?mod=googlenews_wsj
    "online.wsj.com"     => { :regexp => "(\\?|#).*$", :repl => "", :url_changed => false },
        # http://www.stumbleupon.com/s/#33FCbr/http://www.npr.org/templates/story/story.php?storyId=105858495
    "stumbleupon.com"    => { :regexp => "http:.*?/s/#[^/]*/(http://)?(.*)$", :repl => "http://\\2", :url_changed => true, :reset_title => true },
        # URL: http://news.google.com/news/url?sa=T&ct=us/10-0-0&fd=R&url=http://www.nytimes.com/2008/05/22/world/middleeast/22mideast.html%3Fem%26ex%3D1211601600%26en%3D460aa3bd4ac31170%26ei%3D5087%250A&cid=1214621982&ei=Cfs0SKrZC5T8_AH8m4mkCw&usg=AFrqEzevgINgPHTkw8SrzdKsptCwlCpbeA;
    "news.google.com"    => { :regexp => ".*url=(.*)&(cid|usg)=.*", :repl => "\\1", :url_changed => true, :reset_title => true },
  }

    ## For all these domains, the url will be fixed up using a standard rule: url.gsub(/\?.*/, "")
    ## The url parameters for all these domains are basically referrer-tracking parameters
    ## FIXME: Maybe, we can store this info in the database and fetch it from there!
  @@domains_with_default_fixup_rule = [
    # ADD domain of the socialnews site here (ex: socialnews.org)
    "newscientist.com",   # http://www.newscientist.com/channel/opinion/us/dn13998-us-struggling-to-respond-to-climate-shift.html?feedId=us_rss20
    "washingtonpost.com", # http://www.washingtonpost.com/wp-dyn/content/article/2008/05/27/AR2008052702639.html?nav=rss_email/components
    "guardian.co.uk",     # http://www.guardian.co.uk/business/2008/may/28/useconomy.oil?gusrc=rss&feed=worldnews 
    "boston.com",         # http://www.boston.com/news/nation/articles/2008/05/28/for_the_record/?rss_id=Boston+Globe+--+National+News
    "publicradio.org",    # http://minnesota.publicradio.org/projects/2008/05/university_ave/index.shtml?rsssource=1
    "chicagotribune.com", # http://www.chicagotribune.com/news/nationworld/chi-colombia-beetlesjun03,0,939841.story?track=rss
    "latimes.com",        # http://www.latimes.com/news/science/environment/la-fg-food5-2008jun05,0,239303.story?track=rss
    "twincities.com",     # http://www.twincities.com/news/ci_9470322?source=rss
    "mercurynews.com",    # http://www.mercurynews.com/ci_9478902?source=rss
    "seattletimes.nwsource.com", # http://seattletimes.nwsource.com/html/nationworld/2004458821_apforeclosurehelpphiladelphia.html?syndication=rss
    "reuters.com",        # http://www.reuters.com/article/topNews/idUSL0533950720080605?feedType=RSS&feedName=topNews
    "sltrib.com",         # http://www.sltrib.com/news/ci_9688571?source=rv
    "newsweek.com",       # http://www.newsweek.com/id/160482?from=rss
    "salon.com",          # http://www.salon.com/opinion/greenwald/2008/11/30/mccaffrey/index.html?source=newsletter
    "thenation.com",      # http://www.thenation.com/doc/20090126/klein?rel=hp_currently
    "news.sky.com",       # http://news.sky.com/skynews/Home/UK-News/Climate-Change-UK-Must-cut-Emissions-By-Third-In-2020-Says-Government-Committee/Article/200812115170240?lpos=UK_News_Second_UK_News_Article_Teaser_Region_0&lid=ARTICLE_15170240_Climate_Change:_UK_Must_cut_Emissions
    "vanityfair.com",     # http://www.vanityfair.com/politics/features/2009/08/sarah-palin200908?printable=true&currentPage=all
    "gristmill.grist.org", # http://gristmill.grist.org/story/2008/10/15/102131/02?source=daily
    "grist.org", "newyorker.com", "alternet.org", 
    "ft.com", "blog.ft.com", "esquire.com", "cbc.ca", "forbes.com",
    "denverpost.com", "seattlepi.nwsource.com", "slate.com",
    "techcrunch.com", "usatoday.com", "crunchgear.com", "tnr.com", "crooksandliars.com"
  ]

    # These are domains that use toolbars, frames, or proxy pages.  So, we need to extract the target url from these pages.
  @@url_extraction_rules = {
        # <frame name="story" src="..url here.." frameborder="0" marginheight=0 marginwidth=0 noresize>
    "fairspin.org" => %r{<frame\s+name=['"]story['"]\s+src=["'](.*?)["']\s*[^<>]*?>}imx,
        # <iframe id="ext_url_frame" frameborder="0" noresize="noresize" src=".. url here .."></iframe>
    "ginx.com" => %r{<iframe[^<>]*?src="([^<>'"]*?)"></iframe>}imx,
        # <iframe frameborder="0" src="..url here.." ... ></iframe>
    "ow.ly" => %r{<iframe[^<>]*?src="([^<>'"]*?)".*></iframe>}imx,
        # <a href="url here .." title=".." class="DL-external">Full Article at ...</a>
    "daylife.com" => %r{<a\shref=['"]([^<>'"]*)['"]\s[^<>]*class[^<>]*DL-external[^<>]*>Full\s+Article\s+at\s+[^<>]*?</a>}imx,
        # <a class="url external" href="..url here..">..title here..</a>
    "technorati.com" => %r{<a\s*class="url\s+external"\s*href=['"]([^<>'"]*)['"]>.*?</a>}imx,
        # <div id="article-0" class="articletitle"> <h3> <a href=".. url here ..">.. title here ..</a></h3>
    "tipd.com" => %r{<div[^<>]*?class="articletitle">\s*<h3>\s*<a[^<>]*?href="([^<>'"]*)"[^<>]*?>.*?</a>}imx,
       # <a id="article_link_179649100" class="content_link" href=".. url here ..">.. title here ..</a>
    "givemesomethingtoread.com" => %r{<a[^<>]*?class="content_link"[^<>]*?href=['"]([^<>'"]*)['"]>.*?</a>}imx,
       # <div class="article-source"><a href=".. url here .."> Read Full Article
    "realclearpolitics.com" => %r{<div\s*class="article-source"><a\s*href=['"]([^<>'"]*)['"]>\s*Read\s*Full}imx,
  }

  ## This method manipulates the story url according to a set of search-replace rules based on the url-domain
  ## This saves us from having to write similar-looking custom story processors for lots of sources
  def cleanup_url(story)
    url = story.url
    domain = NetHelpers.get_url_domain(url)
    url.gsub!(/&?utm_(campaign|source|medium|content)=[^&]*/, '') # get rid of google analytics tracking
    url.gsub!(/\?$/,'')

    if (!@@domains_with_default_fixup_rule.grep(domain).empty?)
      url.gsub!(/\?.*/, "")
    elsif (fixup_rule = @@url_fixup_rules[domain])
      url.gsub!(/#{fixup_rule[:regexp]}/, "#{fixup_rule[:repl]}")
      return { :url_changed => true, :reset_title => fixup_rule[:reset_title] } if fixup_rule[:url_changed] 
    elsif (url_extraction_rule = @@url_extraction_rules[domain])
        story.url, story.body = NetHelpers.fetch_content(story.url) if story.body.nil? || story.body.empty?
        if story.body =~ url_extraction_rule
          story.url = $1
          return { :url_changed => true, :reset_title => true }
        end
    end
    nil
  end
end
