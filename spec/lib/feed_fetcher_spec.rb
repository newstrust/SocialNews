require File.dirname(__FILE__) + '/../spec_helper'

describe FeedFetcher do
  fixtures :all

      ## BJ apparently has a bug when the timezone is set to UTC 
      ## If we are going to use UTC, we should at least check if
      ## the bug has been fixed and/or what the workaround is.
      ## Till such time, we'll have this assert here
  it 'should check that active record timezone is not UTC' do
    ActiveRecord::Base.default_timezone.should_not == :utc
  end

  it "should ignore an auto-fetched story if the underlying story does not exist" do
    AutoFetchedStory.create(:story_id => 838383)
    lambda do
      lambda do
        FeedFetcher.process_fetched_stories
      end.should change(AutoFetchedStory, :count).by(-1)
    end.should change(ProcessJob, :count).by(0)
  end

  it "should process an auto-fetched story if the underlying story exists" do
    AutoFetchedStory.create(:story_id => stories(:legacy_story).id)
    lambda do
      lambda do
        FeedFetcher.process_fetched_stories
      end.should change(AutoFetchedStory, :count).by(-1)
    end.should change(ProcessJob, :count).by(1)
  end

  describe "story autolisting" do
    before(:each) do
      @story = stories(:legacy_story)
      AutoFetchedStory.create(:story_id => @story.id)
    end

    it "should leave a pending story status untouched if not auto-listing" do
      FeedFetcher.stub!(:should_autolist_story?).and_return(false)
      @story.update_attributes(:status => Story::PENDING)
      FeedFetcher.process_fetched_stories
      @story.reload.status.should == Story::PENDING
    end

    it "should move a pending story status to queued if auto-listing" do
      FeedFetcher.stub!(:should_autolist_story?).and_return(true)
      @story.update_attributes(:status => Story::PENDING)
      FeedFetcher.process_fetched_stories
      @story.reload.status.should == Story::QUEUE
    end

    it "should leave a listed story untouched if auto-listing" do
      FeedFetcher.stub!(:should_autolist_story?).and_return(true)
      @story.update_attributes(:status => Story::LIST)
      FeedFetcher.process_fetched_stories
      @story.reload.status.should == Story::LIST
    end
  end

  describe "processing story feeds" do
    before(:each) do
      @story = stories(:legacy_story)
      @story.feeds = [feeds(:nytimes_top)]
      AutoFetchedStory.create(:story_id => @story.id)
    end

    it "for a story without a story type should set story type to a feed's default story type" do
      @story.update_attributes(:story_type => nil)
      FeedFetcher.process_fetched_stories
      @story.reload.story_type.should == feeds(:nytimes_top).default_stype
    end

    it "for a story with a story type, it should leave the story type unchanged" do
      @story.update_attributes(:story_type => "opinion")
      FeedFetcher.process_fetched_stories
      @story.reload.story_type.should == "opinion"
    end

    it "should add all of a feed's default topic tags to the story" do
      @story.taggings = []
      FeedFetcher.process_fetched_stories
      (feeds(:nytimes_top).default_topics.split(",") - @story.reload.tags.map(&:slug)).should == []
    end
  end

end
