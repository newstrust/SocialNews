require File.dirname(__FILE__) + '/../../spec_helper'

describe "story_processor" do
  fixtures :all

  before(:each) do
    @group = groups(:social_group)
    @story = stories(:legacy_story)
    GroupStory.create(:group_id => @group.id, :story_id => @story.id)
  end

  it "should only compute group ratings when a group is passed in" do
    prs = Ratings.process(@story, false, @group)
    prs.keys.should == [@group.id]
    prs = Ratings.process(@story, true, @group)
    prs.keys.should == [@group.id]
  end

  it "should always compute sitewide ratings when a group is not passed in" do
    prs = Ratings.process(@story, true, nil)
    prs.keys.find { |e| e == 0 }.should == 0
    prs = Ratings.process(@story, false, nil)
    prs.keys.find { |e| e == 0 }.should == 0
  end

  it "should only compute sitewide ratings when the request originates from a web request" do
    prs = Ratings.process(@story, true, nil)
    prs.keys.should == [0]
  end

  it "should compute sitewide & group ratings when the request is a background request" do
    prs = Ratings.process(@story, false, nil)
    prs.keys.sort.should == [0, @group.id]
    g_new = Group.create(:context => Group::GroupType::SOCIAL, :name => "Test Social Group", :slug => "tsg")
    GroupStory.create(:group_id => g_new.id, :story_id => @story.id)
    @story.reload.groups.map(&:id).sort.should == [g_new.id, @group.id].sort
    prs = Ratings.process(@story, false, nil)
    prs.keys.sort.should == [0, @group.id, g_new.id]
  end
end
