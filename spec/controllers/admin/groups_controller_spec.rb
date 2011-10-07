require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::GroupsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  describe "handling GET /admin/groups" do
    before(:each) do
      add_roles
      @params = {}
      @group = mock_model(Group, :id => 1, :slug= => "", :slug => "admin", :add_member => true, :update_attributes => true, :update_attribute => false, :name => 'My Group', :is_social_group? => false, :valid? => true )
    end
    
    def do_get(opts = {})
      get :index, opts
    end
    
    it "should require host access to view this action" do
      check_access_restriction("newshound", "host") do
        do_get @params
      end
      response.should be_success
    end

    it "should return a paginated list of groups and a list of roles" do
      Group.stub!(:paginate).and_return([@group])
      Role.stub!(:find).and_return([@admin_role])
      login_as 'admin'
      do_get
      response.should be_success
      assigns['internal_groups'].length.should == 0  # no internal roles right now
      assigns['roles'].first.name.should =~ /admin/i
      assigns['roles'].first.context == 'role'
    end
  end

  describe "handling GET /adming/groups/new" do
    before(:each) do
      add_roles
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :new, opts
    end

    it "should require staff access to view this action" do
      check_access_restriction("editor", "staff") do
        do_get @params
      end
    end
  end
  
  describe "handling POST /admin/groups" do
    before(:each) do
      add_roles
      @params = { :group => { :name => 'super duper admin', :slug => "super_duper_admin" } }
      @group = mock_model(Group, :id => 1, :slug= => "", :slug => "admin", :add_member => true, :update_attributes => true, :update_attribute => false, :name => 'My Group', :is_social_group? => false, :valid? => true )
    end
    
    def do_post(opts = {})
      post :create, opts
    end
    
    it "should require staff access to view this action" do
      check_access_restriction("editor", "staff") do
        do_post @params
      end
    end
    
    it "should create a new group" do
      login_as 'admin'
      lambda do
        do_post @params
      end.should change(Group, :count).by(1)
      
      response.should redirect_to(admin_group_path(assigns['group']))
      assigns['group'].context.should be_nil
    end
    
    it "should create a new role group" do
      login_as 'admin'
      @params[:group].merge!(:context => 'role')
      lambda do
        do_post @params
      end.should change(Group, :count).by(1)
      response.should redirect_to(admin_group_path(assigns['group']))
      response.flash[:notice].should == "Group Created"
      assigns['group'].context.should == 'role'
    end
    
    it "should return an error if incorrect parameters are supplied" do
      login_as 'admin'
      do_post {}
      response.should render_template('new')
      assigns['group'].errors.should_not be_empty
    end
  end
  
  describe "handling GET /admin/groups/1" do
    before(:each) do
      add_roles
      @params = { :id => 1 }
      @group = mock_model(Group, :id => 1, :slug= => "", :slug => "admin", :add_member => true, :update_attributes => true, :update_attribute => false, :name => 'My Group', :is_social_group? => false, :valid? => true )
    end
    
    def do_get(opts = {})
      get :show, opts
    end
    
    it "should require host access to view this action" do
      check_access_restriction("newshound", "host") do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if incorrect parameters are supplied" do
      login_as 'admin'
      do_get @params.except(:id)
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to the admin dashboard if the group is not found" do
      login_as 'admin'
      Group.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling GET /admin/groups/1/edit" do
    before(:each) do
      add_roles
      @params = { :id => 1 }
      @group = mock_model(Group, :id => 1, :slug= => "", :slug => "admin", :add_member => true, :update_attributes => true, :update_attribute => false, :name => 'My Group', :is_social_group? => false, :valid? => true )
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require editor access to view this action" do
      Group.stub!(:find).and_return(@group)
      check_access_restriction("host", "editor") do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if incorrect parameters are supplied" do
      login_as 'admin'
      do_get @params.except(:id)
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to the admin dashboard if the group is not found" do
      login_as 'admin'
      Group.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should display the requested group" do
      Group.stub!(:find).and_return(@group)
      login_as 'admin'
      do_get @params
      response.should be_success
      assigns['group'].name.should == @group.name
    end
  end
  
  describe "handling PUT /admin/groups/1" do
    before(:each) do
      add_roles
      @group = mock_model(Group, :id => 1, :slug= => "", :slug => "admin", :add_member => true, :update_attributes => true, :update_attribute => false, :name => 'My Group', :is_social_group? => false, :valid? => true )
      Group.stub!(:find).and_return(@group)
      @params = { :id => 1, :group => { :name => 'foo', :context => 'role' }}
    end
    
    def do_put(opts = {})
      put :update, opts
    end

    it "should require editor access to view this action" do
      check_access_restriction("host", "editor") do
        do_put(@params)
      end
      response.should redirect_to(edit_admin_group_path(@group))
    end
    
    it "should update the selected group" do
      login_as 'admin'
      do_put
      response.should redirect_to(edit_admin_group_path(@group))
      response.flash[:notice].should_not be_nil
      assigns['group'].name.should == @group.name
    end
    
    it "should redirect to the group index if the group is not found" do
      login_as 'admin'
      Group.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_put(@params)
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should return an error if incorrect parameters are supplied" do
      @group.stub!(:errors).and_return(mock('errors', :full_messages => ['error']))
      @group.stub!(:valid?).and_return(false)
      login_as 'admin'
      do_put
      response.flash[:notice].should be_nil
      response.should redirect_to(edit_admin_group_path(@group))
    end
  end
    
  describe "handling DELETE /admin/groups/1" do
    before(:each) do
      add_roles
      @group.stub!(:destroy).and_return(true)
      Group.stub!(:find).and_return(@group)
      @params = { :id => 1 }
    end
    
    def do_delete(opts = {})
      delete :destroy, opts
    end
    
    it "should require staff access to view this action" do
      check_access_restriction("host", "staff") do
        do_delete @params
      end
      response.should redirect_to(admin_groups_path)
    end
    
    it "should delete the requested group" do
      login_as 'admin'
      do_delete
      response.flash[:notice].should_not be_nil
      response.should redirect_to(admin_groups_path)
    end
    
    it "should redirect to the group index if the group is not found" do
      login_as 'admin'
      Group.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_delete @params
      response.should redirect_to(admin_groups_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to edit if the group is protected and cannot be deleted" do
      login_as 'admin'
      @group.stub!(:errors).and_return(mock('errors', :full_messages => ['error']))
      @group.stub!(:destroy).and_return(false)
      do_delete @params
      response.should redirect_to(edit_admin_group_path(@group))
    end
  end
end
