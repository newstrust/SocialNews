require File.dirname(__FILE__) + '/../../spec_helper'

module MembersControllerHelper
  def add_members_to_group
    @group.stub_association!(:members, :<< => true, :delete => true, :find => [@member], :paginate => [@member])
    Group.stub!(:find).and_return(@group)
  end  
end

describe Admin::MembersController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  include MembersControllerHelper

  describe "handling GET /groups/1/members/all" do
    before(:each) do
      add_roles
      add_members_to_group
      @params = {}
    end
    
    def do_get(opts = {})
      get :index, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
      assigns['members'].should_not be_empty
    end
  end

  describe "handling GET /groups/1/members/all.js" do
    before(:each) do
      @member = mock_member
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :format => 'js' }
    end
    
    def do_get(opts = {})
      get :index, opts
    end
    
    it "should return a json list of members" do
      should_be_admin_only do
        do_get @params
      end
      json_response = ActiveSupport::JSON.decode(@response.body)
      json_response.first["email"].should == @member.email
      assigns['members'].should_not be_empty
    end
  end
  
  describe "handling GET /groups/1/members/new" do
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1 }
    end
    
    def do_get(opts = {})
      get :new, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end    
  end
  
  describe "handling POST /groups/1/members/join" do
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :id => 1 }
    end
    
    def do_post(opts = {})
      post :join, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_post @params
      end
      response.should redirect_to(admin_group_members_path(@group))
    end
    
    it "should add a member to a group" do
      login_as 'admin'
#      @group.members.stub!(:<<).and_return(true)
      @group.stub!(:add_member).and_return(true)
      do_post @params
      response.flash[:notice].should == "The member has joined the group."
      response.should redirect_to(admin_group_members_path(@group))
    end
    
    it "should display an error if the member cannot join a group" do
      login_as 'admin'
#      @group.members.stub!(:<<).and_return(false)
      @group.stub!(:add_member).and_return(false)
      do_post @params
      response.flash[:error].should == "The member could not join the group."
      response.should redirect_to(admin_group_members_path(@group))
    end
    
    it "should redirect to the admin dashboard if the member is not found" do
      login_as 'admin'
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_post @params
      response.should redirect_to(admin_group_members_path(@group))
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling GET /groups/1/members/1" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :id => 1 }
    end
    
    def do_get(opts = {})
      get :show, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect if the member is not found" do
      login_as 'admin'
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_group_members_path(@group))
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling GET /groups/1/members/1/edit" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :id => 1 }
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if the member is not found" do
      login_as 'admin'
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_group_members_path(@group))
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling PUT /groups/1/members/1" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :id => 1 }
    end
    
    def do_put(opts = {})
      put :update, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_put @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if the member is not found" do
      login_as 'admin'
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_put @params
      response.should redirect_to(admin_group_members_path(@group))
      response.flash[:error].should_not be_nil
    end
    
    it "should update the membership attributes for this member and group."
    
  end

  describe "handling DELETE /groups/1/members/1/leave" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      add_members_to_group
      @params = { :group_id => 1, :id => 1 }
    end
    
    def do_delete(opts = {})
      delete :leave, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_delete @params
      end
      response.should redirect_to(admin_group_members_path(@group))
    end
    
    it "should redirect to the admin dashboard if the member is not found" do
      login_as 'admin'
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_delete @params
      response.should redirect_to(admin_group_members_path(@group))
      response.flash[:error].should_not be_nil
    end
    
    it "should remove the member from the group but not the member itself from the database" do
      @group.members.stub!(:delete).and_return(true)
      login_as 'admin'
      do_delete @params
      response.flash[:notice].should == "The member has been removed from the group"
      response.should redirect_to(admin_group_members_path(@group))
    end
    
    it "should display an error if it could not remove the member from the group" do
      @group.members.stub!(:delete).and_return(false)
      login_as 'admin'
      do_delete @params
      response.flash[:error].should == "The member could not be removed from the group."
      response.should redirect_to(admin_group_members_path(@group))
    end
  end

  describe "termination spammers" do
    fixtures :all
    before(:each) do 
      add_roles
      login_as 'admin'
      @m1 = members(:legacy_member)
      @m2 = members(:heavysixer)
      @m3 = members(:untrustworthy_member)
    end
    
    def do_post(opts = {})
      post :terminate_spammers, opts
    end

    it "should mark spammers deleted" do
      do_post :ids => [@m1.id,@m2.id] * ","
      @m1.reload.status.should == Member::TERMINATED
      @m2.reload.status.should == Member::TERMINATED
    end

    it "should add an editorial note with terminator's name and time of termination" do
      do_post :ids => "#{@m1.id}"
      @m1.reload.status.should == Member::TERMINATED
      @m1.edit_notes.should =~ %r|Terminated by .*? @ \d+/\d+/\d+|
    end

    it "should not terminate members with validation levels 3 and above" do
      @m1.status.should_not == Member::TERMINATED
      @m1.update_attribute(:validation_level, 3)
      do_post :ids => "#{@m1.id}"
      @m1.reload.status.should_not == Member::TERMINATED
      @m1.edit_notes.should_not =~ %r|Terminated by .*? @ \d+/\d+/\d+|
    end

    it "should mark spammers' submitted stories hidden" do
      s1 = Story.find(1); s1.submitted_by_member = @m1; s1.save!
      s2 = Story.find(2); s2.submitted_by_member = @m1; s2.save!
      do_post :ids => "#{@m1.id}"
      s1.reload.status.should == Story::HIDE
      s2.reload.status.should == Story::HIDE
    end

    it "should submit spammers' reviewed stories for recalc" do
      r1 = Review.find(1); r1.update_attributes({:status => "list", :story_id => 1, :member_id => @m2.id})
      r2 = Review.find(2); r2.update_attributes({:status => "list", :story_id => 2, :member_id => @m2.id})
      s1 = Story.find(1); s1.update_attribute(:status, Story::LIST)
      s2 = Story.find(2); s2.update_attribute(:status, Story::LIST)
      ProcessJob.delete_all
      do_post :ids => "#{@m2.id}"
      pjs = ProcessJob.find_all_by_processable_type("Story")
      pjs.map(&:processable_id).sort.should == [1,2]
    end

    it "should not submit spammers' reviewed stories for recalc if they are not public" do
      r1 = Review.find(1); r1.update_attributes({:status => "list", :story_id => 1, :member_id => @m2.id})
      r2 = Review.find(2); r2.update_attributes({:status => "list", :story_id => 2, :member_id => @m2.id})
      s1 = Story.find(1); s1.update_attribute(:status, Story::LIST)
      s2 = Story.find(2); s2.update_attribute(:status, Story::HIDE)
      ProcessJob.delete_all
      do_post :ids => "#{@m2.id}"
      pjs = ProcessJob.find_all_by_processable_type("Story")
      pjs.map(&:processable_id).sort.should == [1]
    end

    it "should record ip addresses of spammers" do
      spammer_ip = "128.1.34.534"
      @m1.http_x_real_ip = spammer_ip; @m1.save!
      SpammerIp.delete_all
      do_post :ids => "#{@m1.id}"
      sip = SpammerIp.find_by_ip(spammer_ip)
      sip.should_not be_nil
      sip.spammer_count.should == 1
    end

    it "should bump spammer_count for ip addresses that are already in the spammer ip table" do
      spammer_ip = "128.1.34.534"
      @m1.http_x_real_ip = spammer_ip; @m1.save!
      SpammerIp.delete_all
      SpammerIp.create(:ip => spammer_ip, :spammer_count => 2)
      do_post :ids => "#{@m1.id}"
      SpammerIp.find_by_ip(spammer_ip).spammer_count.should == 3
    end

    it "should identify additional spammers if their ips match those of the newly terminated members" do
      spammer_ip = "128.1.34.534"
      @m1.http_x_real_ip = spammer_ip; @m1.save!
      @m2.http_x_real_ip = spammer_ip; @m2.save!
      do_post :ids => "#{@m1.id}"
      assigns[:other_spammers].should == [@m2]
    end
  end
end
