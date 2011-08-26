require File.dirname(__FILE__) + '/../spec_helper'

describe FeedParser do
  self.use_transactional_fixtures = false
  fixtures :all

  before(:all) do
    server  = APP_DEFAULT_URL_OPTIONS[:host]
    port    = APP_DEFAULT_URL_OPTIONS[:port]
    server += ":#{port}" if !port.blank?
    dbconf  = Rails::Configuration.new.database_configuration[RAILS_ENV]
    @fp = FeedParser.new(:server_url => "http://#{server}", :mysql_server => "#{dbconf["host"]}", :mysql_user => "#{dbconf["username"]}", :mysql_password => "#{dbconf["password"]}", :mysql_db => "#{dbconf["database"]}")
  end

  after(:all) do
    @fp.shutdown
  end

  it "should fetch existing story if the url matches" do
    s = stories("legacy_story")
    ss = FeedParser::StoryStub.new(:url => s.url)
    ss.id.should == s.id
    ss.status.should == s.status
    ss.story_date.should == s.story_date
  end

  it "should fetch existing story if the url matches an alternate url for a story" do
    au = story_urls("legacy_story_alt_url")
    ss = FeedParser::StoryStub.new(:url => au.url)
    ss.id.should == au.story_id
  end

  it "should fetch existing story attributes" do
    s = stories("legacy_story")
    s.update_attributes(:debug_excerpt => "rss_feed")
    s.reload.debug_excerpt == "rss_feed"
 
    ss = FeedParser::StoryStub.new(:url => s.url)
    ss.id.should == s.id
    ss.load_attribute("debug_excerpt").should == "rss_feed"
  end

  it "should store new story attributes" do
    s = stories("legacy_story")
    ss = FeedParser::StoryStub.new(:url => s.url)
    ss.id.should == s.id
    ss.store_attribute("debug_excerpt", "dummy")
    ss.load_attribute("debug_excerpt").should == "dummy"
    s.reload.debug_excerpt.should == "dummy"
  end
end
