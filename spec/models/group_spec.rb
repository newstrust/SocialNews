require File.dirname(__FILE__) + '/../spec_helper'

describe Group do
  fixtures :all
  before(:each) do
    @group = groups(:admins)
    @member = members(:heavysixer)
    @m_11 = Member.find(11)
    @m_13 = Member.find(13)
  end

  it "should be able to add and remove members" do
    lambda do
      @group.members << @member
    end.should change(Membership, :count).by(1)
    @group.reload.memberships_count.should == 1
    @group.members.include?(@member).should be_true
    
    lambda do
      @group.members.delete @member
    end.should change(Membership, :count).by(-1)
    @group.reload.memberships_count.should == 0
    @group.members.should be_empty
  end
  
  it "should not add the same user twice" do
   lambda do
     @group.members << @member
   end.should change(Membership, :count).by(1)
   
   lambda do
     @group.members << @member
   end.should_not change(Membership, :count)
  end
  
  it "should allow private members who do not appear in the list of members" do
    lambda do
      @group.memberships.create(:member_id => @member.id, :public => false)
    end.should change(Membership, :count).by(1)
    @group.members(true).should be_empty
    @group.private_members(true).include?(@member).should be_true
    
    @group.members.count.should == 0
  end
  
  it "should not delete protected groups" do
    lambda do
      group = groups(:admins)
      group.destroy
      group.errors.on(:base).should eql('This group is protected, and cannot be deleted.')
    end.should_not change(Group, :count)

    # A non protected group can be deletd though
    lambda do
     group = groups(:group_13)
     group.destroy
    end.should change(Group, :count).by(-1)
  end
  
  it "should allow one group with the same name per context" do
    lambda do
      @group = Group.create_with(:name => 'admins', :slug => "admins", :description => 'admins only', :context => 'permission_group')
    end.should change(Group, :count).by(1)
    @group.context.should == 'permission_group'
    
    lambda do
      @group = Group.create_with(:name => 'admins', :slug => "admins-2", :description => 'admins only', :context => 'permission_group')
    end.should_not change(Group, :count)
    @group.errors.on(:name).should =~ /already been taken/
    
    lambda do
      @group = Group.create_with(:name => 'admins', :slug => 'admins_members', :description => 'members who are admins.', :context => 'member_group')
    end.should change(Group, :count).by(1)
    @group.context.should == 'member_group'
  end
  
  it "should define roles based on context" do
    @member.groups << @group
    @member.has_role?(:admin).should be_true
  end

  describe "with social context," do 
    before(:each) do
#      @group = groups(:social_group)
      @group = Group.new(:name => "admins", :description => "nothing", :context => "social", :is_protected => true, :slug => "admins")
      @group.sg_attrs = SocialGroupAttributes.new(:visibility => "private", :activated => false, :num_init_story_days => 7, :membership_mode => "open", :listings => "activity most_recent starred", :status => "list", :tag_id_list => "")
      @group.save!
    end

    describe "when inactive" do
      before(:each) do
        @group.is_social_group?.should == true
        @group.update_attributes({:activated => true, :activation_date => Time.now})
        GroupStory.delete_all
        ProcessedRating.delete_all(:group_id => @group.id)
      end

      it "should not add group stories or background rating processor jobs when adding members" do
        lambda do
          lambda do
            @group.add_member(@member)
          end.should_not change(ProcessJob, :count)
        end.should_not change(GroupStory, :count)
      end
    end

    describe "without any topic constraints, when active" do
      before(:each) do
        @group.is_social_group?.should == true
        @group.sg_attrs.update_attribute(:num_init_story_days, 5)
        @group.memberships.each { |m| m.destroy }
        GroupStory.delete_all
        ProcessJob.delete_all

        # Make sure there will be stories by upping the story date for m_11's submits & reviews to after the start of the group date window
        Story.find(:all, :conditions => {:submitted_by_id => [@m_11.id, @m_13.id]}).each { |s| s.update_attributes(:story_date => Time.now, :status => "list") }.size.should > 0
        Review.find(:all, :conditions => {:member_id => [@m_11.id, @m_13.id]}).each { |r| r.update_attributes(:created_at => Time.now, :status => "list") }.size.should > 0
        @group.activate!
        @group.activated?.should == true
        @group.members.count.should == 0
      end

      describe "adding a member" do
        it "should add group stories and background rating process jobs" do
          @group.add_member(@m_11)
          GroupStory.count.should > 0
          n = @group.stories.collect { |s| s.reviews.find_by_member_id(@m_11.id) }.flatten.compact.reject{|r| !r.is_public? }.count
          n.should > 0
          ProcessJob.count(:conditions => {:processable_type => "Review"}).should == n
        end

        it "should add review process jobs for all reviews of a new member" do
          @group.add_member(@m_11)
          ProcessJob.delete_all
          ProcessJob.count.should == 0
          @m_13.update_attribute(:status, "member") # Make the member non-guest
          @group.add_member(@m_13)
          n = @group.stories.collect { |s| s.reviews.find_by_member_id(@m_13.id) }.flatten.compact.reject{|r| !r.is_public? }.count
          n.should > 0
          ProcessJob.count(:conditions => {:processable_type => "Review"}).should == n
        end
      end

      describe "removing a member" do
        it "should remove the member's exclusive story posts and reviews from group stories" do
          @group.add_member(@m_11)
          GroupStory.count.should > 0
          ProcessJob.count.should > 0
          @group.remove_member(@m_11)
          GroupStory.count.should == 0
          ProcessJob.count.should > 0  # on delete, there will be background rating process jobs for updating ratings
        end

        it "should remove the member's exclusive story posts and reviews from group stories" do
          # next test 2 members add and remove 1 and test exclusivity
          @group.add_member(@m_11)
          @group.add_member(@m_13)
          GroupStory.count.should > 0
          @group.remove_member(@m_11)
          GroupStory.count.should > 0 # We'll still have stories from m_13!

          # Story 1 has been reviewed by both 11 & 13, so it should not have been removed
          GroupStory.exists?(:story_id => 1, :group_id => @group.id).should == true

          # Story 2 & 6 has been exclusively reviewed by both 11, so it should have been removed
          GroupStory.exists?(:story_id => 2, :group_id => @group.id).should == false
          GroupStory.exists?(:story_id => 6, :group_id => @group.id).should == false
        end
      end
    end

    describe "with topic constraints, when active" do
    end
  end
end
