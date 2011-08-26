require File.dirname(__FILE__) + '/../../spec_helper'

describe "review_processor" do
  fixtures :all

  before(:each) do
    @group = groups(:social_group)
    @legacy_member = members(:legacy_member)
    @group.activate!
    @group.add_member(@legacy_member)
    s = stories(:legacy_story)
    @review = s.reviews.first || Review.new(:story_id => s, :member_id => @legacy_member.id, :rating => 4)
  end

  it "should only compute group ratings when a group is passed in" do
    prs = Ratings.process(@review, false, @group)
    prs.keys.should == [@group.id]
    prs = Ratings.process(@review, true, @group)
    prs.keys.should == [@group.id]
  end

  it "should always compute sitewide ratings when a group is not passed in" do
    prs = Ratings.process(@review, true, nil)
    prs.keys.find { |e| e == 0 }.should == 0
    prs = Ratings.process(@review, false, nil)
    prs.keys.find { |e| e == 0 }.should == 0
  end

  it "should only compute sitewide ratings when the request originates from a web request" do
    prs = Ratings.process(@review, true, nil)
    prs.keys.should == [0]
  end

  it "should compute sitewide & group ratings when the request is a background request" do
    prs = Ratings.process(@review, false, nil)
    prs.keys.sort.should == [0, @group.id]
  end

  it "should compute group ratings only for the social groups that a member belongs to" do
    g_role = Group.find(:first, :conditions => {:context => Group::GroupType::ROLE})
    g_role.add_member(@legacy_member)
    prs = Ratings.process(@review, false, nil)
    prs.keys.sort.should == [0, @group.id] # g_role should not be present here
  end
end
