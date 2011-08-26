require File.dirname(__FILE__) + '/spec_helper'

class MockMember
  def initialize(opts)
    @roles = opts[:roles] if opts[:roles]
  end
  def roles
    @roles
  end
  
  def has_role?(role)
    @roles.map{ |g| g.name.downcase.to_sym }.include?(role)
  end
end

# This controller simulates a controller that includes AuthenticatedSystem, which the 
# role system can hook into.
class MockApplicationController < ActionController::Base
  
  # Used by the RoleSystem to find the current member (if any)
  # This before filter needs to be called BEFORE any role checking.
  before_filter { |controller| controller.role_player = :current_member }
  
  def access_denied
    redirect_to new_sessions_path and return false
  end
end

module RoleSystemSpecHelper
  def add_roles
    @editor_role = mock_model(Group, :name => 'editor', :context => 'role')
    @admin_role = mock_model(Group, :name => 'admin', :context => 'role')
    @content_editor_role = mock_model(Group, :name => 'content_editor', :context => 'role')
  end
  
  def login_as(role)
    instance_variable_set("@#{role}".to_sym, MockMember.new(:roles => [instance_variable_get("@#{role}_role")]))
    @controller.stub!(:current_member).and_return(instance_variable_get("@#{role}"))
  end  
end

class AdminOnlyController < MockApplicationController
  grant_access_to :admin
  
  def index
  end  
end

describe RoleSystem, "a controller allowing only admin access", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :admin_only
  before(:each) do
    add_roles
  end
  
  it "should allow an admin access" do
    login_as('admin')
    get :index
    response.should be_success
  end
  
  it "should prevent access by anyone who is not an admin" do
    login_as('editor')
    get :index
    response.should redirect_to(new_sessions_path)
  end
end

class MixedRoleAccessController < MockApplicationController
  grant_access_to :content_editor, :only => :new
  grant_access_to :admin,   :only => [:new, :destroy]
  grant_access_to :editor,  :except => :destroy
  
  def index;end
  def new;end
  def destroy;end  
end

describe RoleSystem, "a controller allowing access to actions by role", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :mixed_role_access
  before(:each) do
    add_roles
  end
  
  it "should grant access to content_editor and admin for new" do
    login_as('content_editor')
    get :new
    response.should be_success
    
    login_as('admin')
    get :new
    response.should be_success
  end
  
  it "should grant acccess to editor for index" do
    login_as('editor')
    get :index
    response.should be_success
  end
  
  it "should only give destroy access to admin" do   
    login_as('editor')
    get :destroy
    response.should redirect_to(new_sessions_path)
    
    login_as('admin')
    get :destroy
    response.should be_success
  end
  
  it "should not give access to index to admin" do
    login_as('admin')
    get :index
    response.should redirect_to(new_sessions_path)
  end
end

class ConditionalAccessController < MockApplicationController

  grant_access_to :content_editor, :if => Proc.new { |controller| controller.has_key?(:sekret) }
  grant_access_to :admin, :unless => Proc.new { |controller| controller.has_key?(:admin_sekret) }
  
  def index;end
end

describe RoleSystem, "a controller allowing access under certain conditions", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :conditional_access
  before(:each) do
    add_roles
  end
  
  it "should grant access to admin unless access is revoked ahead of time" do
    login_as('admin')
    get :index
    response.should be_success

    get :index, :admin_sekret => 'shhhhhhhhhhhhhhh'
    response.should redirect_to(new_sessions_path)
  end
  
  it "should allow access to content_editors if special access is granted" do
    login_as('content_editor')
    get :index
    response.should redirect_to(new_sessions_path)
    
    get :index, :sekret => 'shhhhhhhhhhhhhhh'
    response.should be_success
  end
end

class EquivalentAccessController < MockApplicationController
  grant_access_to :admin
  grant_access_to [:content_editor, :editor] , :only => :index
  
  def index;end
  def new;end
end

describe RoleSystem, "a controller where two roles are equivalent", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :equivalent_access
  before(:each) do
    add_roles
  end
  
  it "should treat the roles identically" do
    login_as('admin')
    get :index
    response.should be_success
    
    get :new
    response.should be_success
    
    login_as('editor')
    get :index
    response.should be_success
    
    get :new
    response.should redirect_to(new_sessions_path)

    login_as('content_editor')
    get :index
    response.should be_success
    
    get :new
    response.should redirect_to(new_sessions_path)
  end
end

class AntiAuthenticatedController < ActionController::Base
  include RoleSystem
  before_filter { |controller| controller.role_player = :current_member }
  grant_access_to :admin
  def index;end
end

describe RoleSystem, "a controller without authenticated system", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :anti_authenticated
  before(:each) do
    add_roles
  end
  
  it "should just return an access denied header when authenticated_system is not available" do
    login_as('editor')
    get :index
    response.headers['Status'].should == "401 Unauthorized"
  end
end

class MixedAuthenticatedNonAuthenticatedActionsController < MockApplicationController
  all_access_to :only => [:everybody_allowed]
  grant_access_to [:admin]
  def admin_only;end
  def everybody_allowed;end
end

describe RoleSystem, "a controller where only certain actions require roles", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :mixed_authenticated_non_authenticated_actions
  before(:each) do
    add_roles
  end
  
  it "should allow a member with a role to access both role-requried and public actions" do
    login_as('admin')
    get :admin_only
    response.should be_success
    
    get :everybody_allowed
    response.should be_success
  end
  
  it "should allow members without a role or without being logged in to access public actions" do
    
    # No session at all
    get :admin_only
    response.should redirect_to(new_sessions_path)
    
    get :everybody_allowed
    response.should be_success
    
    login_as('editor')
    get :admin_only
    response.should redirect_to(new_sessions_path)
    
    get :everybody_allowed
    response.should be_success
  end
end

class AnotherMixedAuthenticatedNonAuthenticatedActionsController < MockApplicationController
  all_access_to :except => [:nobody_allowed]
  grant_access_to [:admin]
  def everybody_allowed;end
  def nobody_allowed;end
end

describe RoleSystem, "another controller where only certain actions require roles", :type => :controller do
  include RoleSystemSpecHelper
  controller_name :another_mixed_authenticated_non_authenticated_actions
  before(:each) do
    add_roles
  end
  
  it "should allow a member with a role to access both role-requried and public actions" do
    login_as('admin')
    get :everybody_allowed
    response.should be_success
    
    get :nobody_allowed
    response.should be_success
  end
  
  it "should allow members without a role or without being logged in to access public actions" do
    
    # No session at all
    get :nobody_allowed
    response.should redirect_to(new_sessions_path)
    
    get :everybody_allowed
    response.should be_success
    
    login_as('editor')
    get :nobody_allowed
    response.should redirect_to(new_sessions_path)
    
    get :everybody_allowed
    response.should be_success
  end
end