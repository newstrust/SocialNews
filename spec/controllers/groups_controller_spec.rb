require File.dirname(__FILE__) + '/../spec_helper'

describe GroupsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  fixtures :all

  def do_get(action = :index, opts = {})
    get action, opts
  end

  def do_post(action, opts = {})
    post action, opts
  end

  def do_put(opts = {})
    put :update, opts
  end

  def do_delete(opts = {})
    delete :destroy, opts
  end
  
  before(:each) do
    @social_group = Group.new(:name => "testing", :description => "nothing", :context => "social", :is_protected => true, :slug => "testing")
    @social_group.sg_attrs = SocialGroupAttributes.new(:visibility => "public", :activated => true, :activation_date => Time.now.to_date, :listings => "activity most_recent starred", :status => "list", :tag_id_list => "")
    @social_group.save!
  end

  describe "group landing page" do
    it "should show public groups to everyone" do
      do_get(:show, {:id => @social_group.id})
      response.should be_success
      response.should render_template("show")
    end

    it "should hide public (but with hidden status) groups from guests" do
      @social_group.sg_attrs.update_attribute(:status, "hide")
      do_get(:show, {:id => @social_group.id})
      response.status.should =~ /403/
    end

    it "should show hidden status groups to editors" do
      @social_group.sg_attrs.update_attribute(:status, "hide")
      add_roles
      login_as 'editor'
      do_get(:show, {:id => @social_group.id})
      response.should be_success
    end

    it "should show hidden status groups to group hosts" do
      m = members(:heavysixer)
      spec_login_as(m)
      @social_group.sg_attrs.update_attribute(:status, "hide")

      do_get(:show, {:id => @social_group.id})
      response.status.should =~ /403/

      @social_group.add_host(m)
      do_get(:show, {:id => @social_group.id})
      response.should be_success
    end

    it "should hide private groups from non-members" do
      @social_group.sg_attrs.update_attribute(:visibility, "private")
      do_get(:show, {:id => @social_group.id})
      response.status.should =~ /403/
    end

    it "should show private groups to members" do
      @social_group.sg_attrs.update_attribute(:visibility, "private")
      m = members(:heavysixer)
      @social_group.add_member(m)
      spec_login_as(m)
      do_get(:show, {:id => @social_group.id})
      response.should be_success
      response.should render_template("show")
    end

    it "should ignore local_site when listing stories"

# SSS: Test this in view specs
#
#    it "should show the default tab as the first tab" do
#    @social_group.sg_attrs.update_attributes("default_listing" => "starred")
#      do_get(:show, {:id => @social_group.id})
#      response.should be_success
#       body = response.body
#      i1 = response.body =~ /id="tab_starred"/
#      i2 = response.body =~ /id="tab_activity"/
#      i3 = response.body =~ /id="tab_most_recent"/
#      i3.should < i1
#      i1.should < i2
#    end

  end
end
