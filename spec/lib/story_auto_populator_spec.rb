require File.dirname(__FILE__) + '/../spec_helper'

describe StoryAutoPopulator do
  fixtures :all

  @@googlenews_tests = [
    { :url => "http://news.google.com/news/url?sa=T&ct=us/10-0-0&fd=R&url=http://www.nytimes.com/2008/05/22/world/middleeast/22mideast.html%3Fem%26ex%3D1211601600%26en%3D460aa3bd4ac31170%26ei%3D5087%250A&cid=1214621982&ei=Cfs0SKrZC5T8_AH8m4mkCw&usg=AFrqEzevgINgPHTkw8SrzdKsptCwlCpbeA",
      :domain => "nytimes.com" }
  ]

  @@aggregator_domain_tests = [
    "http://www.memeorandum.com/080927/p56#a080927p56",
    "http://news.google.com/news/url?sa=T&ct=us/10-0-0&fd=R&url=http://www.nytimes.com/2008/05/22/world/middleeast/22mideast.html%3Fem%26ex%3D1211601600%26en%3D460aa3bd4ac31170%26ei%3D5087%250A&cid=1214621982&ei=Cfs0SKrZC5T8_AH8m4mkCw&usg=AFrqEzevgINgPHTkw8SrzdKsptCwlCpbeA"
  ]

  @@proxy_tests = [
    "http://feeds.feedburner.com/~r/AbcNews_ThisWeek/~3/162654143/story",
    "http://www.pheedo.com/click.phdo?i=fabc2681e50b765c68e4e0b1bdde440f",
    "http://feeds.sfgate.com/~r/sfgate/rss/feeds/opinion/~3/299652042/article.cgi",
  ]

  @@proxy_targets = {
    "http://feeds.feedburner.com/~r/AbcNews_ThisWeek/~3/162654143/story"  => "http://abcnews.go.com/Politics/TheNote/story?id=3105288&page=1",
    "http://www.pheedo.com/click.phdo?i=fabc2681e50b765c68e4e0b1bdde440f" => "http://www.newscientist.com/channel/opinion/us/dn13998-us-struggling-to-respond-to-climate-shift.html?feedId=us_rss20",
    "http://feeds.sfgate.com/~r/sfgate/rss/feeds/opinion/~3/299652042/article.cgi" => "http://www.newscientist.com/channel/opinion/us/dn13998-us-struggling-to-respond-to-climate-shift.html?feedId=us_rss20",
  }

  @@blog_story_type_tests = [
    #"http://riverbendblog.blogspot.com/2004_01_01_riverbendblog_archive.html",
    #"http://avc.blogs.com/a_vc/2008/02/journabloggers.html",
    #"http://bits.blogs.nytimes.com/2008/06/30/google-and-the-anti-obama-bloggers/",
    #"http://ak-daughterofthelake.blogspot.com/2006/07/2010-tents-and-armed-babes-in-uniform.html",
    #"http://aldon.livejournal.com/84004.html",
    #"http://0u812.wordpress.com/2007/12/20/the-trouble-with-propaganda-and-prohibition/"
  ]

  @@failed_blog_story_type_tests = [
    #"http://brainblogger.com/2008/04/15/encephalon-forthy-third-edition/"
  ]

  @@successful_date_inferences = [
    { :date => "20080206", :url => "http://www.examiner.com/blogs/tapscotts_copy_desk/2008/2/6/Now-we-see-if-McCain-really-wants-conservatives" },
    { :date => "20080128", :url => "http://thinkprogress.org/2008/01/28/embargoed-state-of-the-union-text-2/" },
    { :date => "20080104", :url => "http://www.csmonitor.com/2008/0104/p02s01-usgn.html" },
    { :date => "20080206", :url => "http://www.lasvegassun.com/news/2008/feb/06/reid-renewables-shorted-bush-budget/" },
    { :date => "20070508", :url => "http://www.voanews.com/english/2007-05-08-voa65.cfm" },
    { :date => "20070102", :url => "http://www.cnn.com/2007/WORLD/asiapcf/01/02/australia.aborigine.reut/index.html" },
    { :date => "20070122", :url => "http://www.businessweek.com/print/technology/content/jan2007/tc20070122_842933.htm" },
    { :date => "20070808", :url => "http://www.columbiatribune.com/2007/Aug/20070808Comm002.asp" },
    { :date => "20070219", :url => "http://news.enquirer.com/apps/pbcs.dll/article?AID=/20070219/EDIT02/702190317/1090" },
  ]

  @@login_screen_tests = [
    { :url => "http://www.washingtonpost.com/ac2/wp-dyn?node=admin/registration/register&destination=login&nextstep=gather&application=reg30-world&applicationURL=http://www.washingtonpost.com/wp-dyn/content/article/2009/04/12/AR2009041202809.html", :result => true },
    { :url => "http://www.washingtonpost.com/wp-dyn/content/article/2009/04/12/AR2009041202809.html", :result => false }
  ]

  def get_story(url)
     story = Story.new
     story.url = url
     return story
  end

  def has_proxy_domain(u)
    NetHelpers.is_proxy_domain(NetHelpers.get_url_domain(u))
  end

#  describe 'identifying wire service attributions' do
#    before(:each) do
#      @samples_dir = "#{RAILS_ROOT}/spec/lib/webpage_samples"
#      MetadataFetcher::Daylife.stub!(:get_metadata).and_return(nil)
#      StoryAutoPopulator.stub!(:update_story_metadata_from_apis).and_return(nil)
#    end
#
#    it 'should attribute story to AP when attribution is at the beginning' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Israel rebuffs U.S. call for total settlement freeze - Haaretz - Israel News" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/haaretz_ap_test.html") }
#      story = get_story("http://www.haaretz.com/hasen/spages/1088799.html")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "associated_press" }.should_not be_nil
#    end
#
#    it 'should attribute story to AP when copyright notice is at the bottom' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Maine bill promotes solar power" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/boston_globe_ap_test.html") }
#      story = get_story("http://www.boston.com/news/local/maine/articles/2009/05/28/maine_bill_promotes_solar_power/")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "associated_press" }.should_not be_nil
#    end
#
#    it 'should ignore wire service attribution in the middle of the article' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Greenwash: E-waste trade is the unacceptable face of recycling" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/guardian_ap_test.html") }
#      story = get_story("http://www.guardian.co.uk/environment/2009/may/28/greenwash-electronic-waste")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "associated_press" }.should be_nil
#    end
#
#    it 'should ignore wire service attribution that are actually for an image - 1' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Doesn't matter" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/nytimes_img_ap.html") }
#      story = get_story("http://www.nytimes.com/2009/08/29/us/29abduct.html")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "associated_press" }.should be_nil
#    end
#
#    it 'should ignore wire service attribution that are actually for an image - 2' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Doesn't matter" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/nyt.10mar2010.10biden.html") }
#      story = get_story("http://www.nytimes.com/2010/03/10/world/middleeast/10biden.html?ref=world")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "reuters" }.should be_nil
#    end
#
#    it 'should not ignore wire service attribution if there is a non-image attribution even if there is another image attribution' do
#      StoryAutoPopulator.should_receive(:set_story_title).and_return {|s| s.title = "Doesn't matter" }
#      StoryAutoPopulator.should_receive(:fetch_story_content).and_return { |s| s.body = File.read("#{@samples_dir}/boston_globe_img_and_text_wire_service.html") }
#      story = get_story("http://www.boston.com/news/nation/articles/2009/08/30/3_homes_destroyed_many_more_threatened_by_ca_fire/")
#      StoryAutoPopulator.populate_story_fields(story)
#      story.authorships.to_ary.find { |a| a.source.slug == "associated_press" }.should_not be_nil
#    end
#  end

  describe 'populating all story fields' do
        ## Don't go onto the net
    before(:each) do
      StoryAutoPopulator.stub!(:fetch_story_content).and_return("")
      StoryAutoPopulator.should_receive(:set_story_title).any_number_of_times.and_return {|s| s.title = "Dummy Title" }
      MetadataFetcher::Daylife.stub!(:get_metadata).and_return(nil)
      StoryAutoPopulator.stub!(:update_story_metadata_from_apis).and_return(nil)
    end

    it 'should follow proxies' do
      @@proxy_tests.each { |u|
        story = get_story(u)

          ## Trap the get_302_target message which goes onto the net ... and return the target url
        NetHelpers.should_receive(:get_302_target).with(u).and_return { |u| @@proxy_targets[u] }

          ## Before & after!
        has_proxy_domain(story.url).should be_true
        StoryAutoPopulator.populate_story_fields(story)
        has_proxy_domain(story.url).should be_false

          ## Other things
        ## story.title.should_not be_nil -- Cannot test this without really going out onto the net
        story.authorships.should_not be_empty
        story.authorships.first.source.domain.should_not be_nil
      }
    end

    it 'should extract info from google news urls' do
      @@googlenews_tests.each { |t|
        story = get_story(t[:url])

        StoryAutoPopulator.populate_story_fields(story)
        ## story.title.should_not be_nil -- Cannot test this without really going out onto the net
        story.authorships.should_not be_empty
        story.authorships.first.source.domain.should == t[:domain]
        (story.url =~ /news.google.com/).should be_nil
      }
    end

    it 'should build new sources if there is no match with existing sources' do
      url = "http://www.hindu.com/2008/08/03/stories/2008080361271700.htm"
      story = get_story(url)
      lambda do
        StoryAutoPopulator.populate_story_fields(story)
      end.should change(Source, :count).by(1)
    end

    it 'should set the right source for urls with source subdomains' do
      url = "http://thecaucus.blogs.nytimes.com/2007/03/16/mccain-stumbles-on-hiv-prevention/"
      story = get_story(url)
      lambda do
        StoryAutoPopulator.populate_story_fields(story)
        story.rating = 0.0
        story.save!
      end.should change(Authorship, :count).by(1)

        ## Refetch the story from the db
      story = Story.find_by_url(url)
      story.primary_source.should_not be_nil
      story.primary_source.domain.should == 'nytimes.com'
    end

    it 'should process the story through a custom story processor where one exists' do
      url = 'http://www.nytimes.com/2008/08/25/business/25gas.html?partner=rssnyt&emc=rss'
      story = get_story(url)

      extra_info = StoryAutoPopulator.populate_story_fields(story)
      story.url.should == "http://www.nytimes.com/2008/08/25/business/25gas.html"
      extra_info.should_not be_nil
    end

    it 'should not overwrite the results of the custom story processor' do
      url = 'http://www.nytimes.com/2008/08/25/opinion/25mon4.html?partner=rssnyt&emc=rss'
      story = get_story(url)
      extra_info = StoryAutoPopulator.populate_story_fields(story)
      story.story_type.should == 'opinion'
    end

    it 'should not set/build sources with aggregator domains' do
      @@aggregator_domain_tests.each { |u|
        story = get_story(u)
        StoryAutoPopulator.populate_story_fields(story)
        story.authorships.each { |a| StoryAutoPopulator.is_aggregator_domain?(a.source.domain).should be_false }
      }
    end

    it "should extract target url from #{SocialNewsConfig["app"]["name"]} urls"
  end

  describe 'populating specific fields' do
    it 'should successfully infer story dates' do
      @@successful_date_inferences.each { |u|
        story = get_story(u[:url])
        StoryAutoPopulator.set_story_date(story)
        story.story_date.should_not be_nil
        story.story_date.strftime("%Y%m%d").should == u[:date]
      }
    end

    it 'should infer story type for blog posts' do
      @@blog_story_type_tests.each { |u|
        story = get_story(u)
        StoryAutoPopulator.set_story_format(story)
        story.story_type.should =~ /Opinion/i
      }
      @@failed_blog_story_type_tests.each { |u|
        story = get_story(u)
        StoryAutoPopulator.set_story_format(story)
        story.story_type.should !~ /Opinion/i
      }
    end

    it 'should set the right subdomain source where there exists a source with a matching subdomain'

    it 'should properly identify login screens' do
      @@login_screen_tests.each { |t| NetHelpers.is_login_screen_url(t[:url]).should == t[:result] }
    end
  end
end
