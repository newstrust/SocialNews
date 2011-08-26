require File.dirname(__FILE__) + '/../spec_helper'

describe CustomStoryProcessors do
  def get_story(url)
     story = Story.new
     story.url = url
     return story
  end

  describe 'default url modification rules' do
    before(:each) do
      @tests = [
        "http://www.boston.com/news/nation/articles/2008/05/28/for_the_record/?rss_id=Boston+Globe+--+National+News",
        "http://seattletimes.nwsource.com/html/nationworld/2004458821_apforeclosurehelpphiladelphia.html?syndication=rss"
      ]
    end

    it 'should remove url tracking attributes' do
      @tests.each { |u|
        story  = get_story(u)
        retval = CustomStoryProcessors.generic_url_fixup(story)
        retval.should be_nil
        (story.url =~ /\?.*/).should be_nil ## all ?.* url params should be stripped out!
      }
    end
  end

  describe 'source-specific url modification rules' do
    before(:each) do
      @tests = [
        "http://www.sfgate.com/cgi-bin/article.cgi?f=/c/a/2008/05/28/ED2K10U856.DTL&feed=rss.opinion",
        "http://www.marketwatch.com/news/story/mishkin-resigning-fed-return-academia/story.aspx?guid={B82EF056-B712-42C7-BAF8-F02886D12DC4}&dist=msr_7",
        "http://www.cbsnews.com/video/watch/?id=4493093n?source=mostpop_video",
        "http://news.newamericamedia.org/news/view_article.html?article_id=3172f2965d1a32817bff097afa501763&from=rss"
      ]
    end

    it 'should remove url tracking attributes' do
      @tests.each { |u|
        story  = get_story(u)
        retval = CustomStoryProcessors.generic_url_fixup(story)
        retval.should be_nil
          ## For these specific tests, there should be no &.* params left,
        (story.url =~ /\&.*/).should be_nil 
          ## but, it should retain the atleast some "?" params
        (story.url =~ /\?.*/).should_not be_nil 
      }
    end
  end

  describe 'nytimes story processor' do
    before(:each) do
      @tests = [
        { :url    => "http://www.nytimes.com/2008/07/27/opinion/27rich.html?partner=rssnyt&emc=rss",
          :story_type => "opinion",
          :tags   => [],
          :topics => [] },
        { :url => "http://www.nytimes.com/2008/07/29/business/29hip.html?em&ex=1217476800&en=20c1a469134f79d6&ei=5087%0A",
          :story_type => nil,
          :tags   => ["Business"],
          :topics => [] },
      ]
    end

    it 'should remove url tracking attributes' do
      @tests.each { |t|
        story  = get_story(t[:url])
        retval = CustomStoryProcessors.new_york_times_process_story(story, nil)
        (story.url =~ /\?.*/).should be_nil
      }
    end

    it 'should infer additional information from the url' do
      @tests.each { |t|
        story  = get_story(t[:url])
        retval = CustomStoryProcessors.new_york_times_process_story(story, nil)
        story.story_type.should == t[:story_type]
        retval[:topics] == t[:topics]
        retval[:tags] == t[:tags]
      }
    end
  end
end
