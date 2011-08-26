require File.dirname(__FILE__) + '/../spec_helper'

describe Save do
  fixtures :all
  
  before(:each) do
    @legacy_member = members(:legacy_member)
    @legacy_story = stories(:legacy_story)
  end
  
  it "should only allow one star" do
    @legacy_story.saves.should be_empty
    @legacy_member.saves << Save.new(:story => @legacy_story)
    @legacy_member.save
    @legacy_story.reload.saves.length.should eql(1)
    @legacy_member.saves << Save.new(:story => @legacy_story)
    @legacy_member.save
    @legacy_story.reload.saves.length.should eql(1)
  end

  describe " in the presence of social groups:" do
    before(:each) do
      @group = groups(:social_group)
      @group.update_attributes({:activated => true, :activation_date => Time.now})
      GroupStory.delete_all
    end

    describe "with starring: " do
      it "should not add new group stories after a star if the starrer does not belong to any social group" do
        Save.create(:story_id => @legacy_story.id, :member_id => @legacy_member.id)
        GroupStory.count.should == 0
      end

      it "should add new group stories after a star for all social groups that the starrer belongs to" do
        @group.members << @legacy_member
        Save.create(:story_id => @legacy_story.id, :member_id => @legacy_member.id)
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == true
      end
    end

    describe "unstarring: " do 
      before(:each) do
        @group.members << @legacy_member

        # clear out all stars, reviews, and submits so that legacy member's star is the only thing that influences story membership for groups
        @legacy_story.update_attribute(:submitted_by_id, 1)
        @legacy_story.saves.each { |s| s.delete }
        @legacy_story.reviews.each { |r| r.destroy }

        # Create a star
        @save = Save.create(:story_id => @legacy_story.id, :member_id => @legacy_member.id)
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == true
      end

      it "should remove the unstarred story from a social group that no longer has a starrer, poster, or reviewer from that group" do
        @save.destroy
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == false
      end

      it "should not remove the unstarred story from a social group that still has a poster from that group" do
        @legacy_story.update_attribute(:submitted_by_id, @legacy_member.id)
        gs = GroupStory.find(:all, :conditions => {:group_id => @group.id})
        @save.story.reload
        @save.destroy
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == true
        gs = GroupStory.find(:all, :conditions => {:group_id => @group.id})
      end

      it "should not remove the unstarred story from a social group that still has a reviewer from that group" do
        Review.create(:story_id => @legacy_story.id, :member_id => @legacy_member.id)
        @save.destroy
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == true
      end

      it "should not remove the unstarred story from a social group that still has a starrer from that group" do
        Save.create(:story_id => @legacy_story.id, :member_id => members(:heavysixer).id)
        @group.members << members(:heavysixer)
        @save.destroy
        GroupStory.exists?(:story_id => @legacy_story.id, :group_id => @group.id).should == true
      end
    end
  end
end
