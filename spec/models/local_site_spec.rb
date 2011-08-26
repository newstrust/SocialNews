require File.dirname(__FILE__) + '/../spec_helper'

describe LocalSite do
  fixtures :all

  # Right now, the only constraints on local sites are tags!
  # If this changes, change this spec and all dependent code in the app
  it "should always return a non-nil constraining tag" do
    LocalSite.create(:name => "Health Local Site", :slug => "health", :subdomain => "health", :constraint_type => "Tag", :constraint_id => 10, :is_active => true)
    lsc = LocalSite.find(:last).constraint
    lsc.should_not be_nil
    [Tag].include?(lsc.class).should be_true
  end

  it "should always return a local story scope" do
    LocalSite.new.default_story_scope.should == Story::StoryScope::LOCAL
  end

  describe "max_stories_per_source" do
    it "should be 1 for national site" do
      LocalSite.max_stories_per_source(nil).should == 1
    end

    it "should be nil for local site if field is blank" do
      l = LocalSite.new(:name => "Test", :slug => "abcd", :subdomain => "abcd", :max_stories_per_source => "")
      LocalSite.max_stories_per_source(l).should be_nil
    end

    it "should return local site setting if field is not blank" do
      l = LocalSite.new(:name => "Test", :slug => "abcd", :subdomain => "abcd", :max_stories_per_source => 50)
      LocalSite.max_stories_per_source(l).should == 50
    end
  end
end
