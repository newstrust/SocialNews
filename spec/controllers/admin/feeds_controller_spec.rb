require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::FeedsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :all

  before(:each) do
    add_roles
    @feed = feeds(:nytimes_top)
    @params = {}
  end
    
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

  it "should require admin access to view GET /admin/feeds" do
    should_be_admin_only('host') do
      do_get
    end
    response.should be_success
  end

  it "should return a paginated list of feeds for GET /admin/feeds" do
    login_as 'admin'
    do_get
    response.should be_success
    assigns['feeds'].size.should > 0
  end

  it "should create a new feed object for GET /admin/feeds/new" do
    login_as 'admin'
    do_get :new
    assigns['feed'].should_not be_nil
    assigns['feed'].id.should be_nil
  end

  it "should add a new feed for POST /admin/feeds" do
    login_as 'admin'
    FeedHelpers.stub!(:update_feed_attributes).and_return({:url => "http://nowhere.com/rss.xml", :home_page => "http://nowhere.com", :name => "NoWhere!", :desc => "This is a place you will get nowhere"})
    lambda do
      do_post :create, { :feed => { :url => "http://nowhere.com/rss.xml" } }
    end.should change(Feed, :count).by(1)
  end

  it "should update an existing feed for PUT /admin/feeds/1" do
    login_as 'admin'
    do_put({ :id => 1, :feed => { :auto_fetch => false } })
    Feed.find(1).auto_fetch.should be_false
  end

  it "should delete an existing feed for DELETE /admin/feeds/1" do
    login_as 'admin'
    lambda do 
      do_delete({ :id => 1 })
    end.should change(Feed, :count).by(-1)
  end

  it "should fetch the feed for GET /admin/feeds/1/test"
end
