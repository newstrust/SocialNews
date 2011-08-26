require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::EditorialSpacesController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :all

  before(:each) do
    add_roles
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

  it "should require admin access to view GET /admin/editorial_spaces/new" do
    should_be_admin_only('host') do
      do_get :new
    end
    response.should be_success
  end

  it "should create a new editorial space object for GET /admin/editorial_spaces/new" do
    login_as 'admin'
    do_get :new
    assigns['editorial_space'].should_not be_nil
    assigns['editorial_space'].id.should be_nil
    assigns['editorial_space'].page.should be_nil
  end

  it "should create a new editorial space object for GET /admin/editorial_spaces/new?page_type=Topic&page_id=1" do
    login_as 'admin'
    do_get :new, :page_type => "Topic", :page_id => 1
    assigns['editorial_space'].should_not be_nil
    assigns['editorial_space'].id.should be_nil
    assigns['editorial_space'].page.should == Topic.find(1)
  end

  it "should add a new editorial space for POST /admin/editorial_spaces" do
    login_as 'admin'
    lambda do
      do_post :create, { :page_type => "", :page_id => "", :editorial_space => { :name => "test 1", :show_name => 1, :position => 1 } }
    end.should change(EditorialSpace, :count).by(1)
    lambda do
      do_post :create, { :editorial_space => { :name => "test 2", :show_name => 0, :position => 2 } }
    end.should change(EditorialSpace, :count).by(1)
  end

  it "should add a new editorial space for POST /admin/editorial_spaces?page_type=Topic&page_id=1" do
    login_as 'admin'
    lambda do
      do_post :create, { :page_type => 'Topic', :page_id => 1, :editorial_space => { :name => "test", :show_name => 1, :position => 1 } }
    end.should change(EditorialSpace, :count).by(1)
	  EditorialSpace.find(:last).page.should == Topic.find(1)
  end

  it "should update existing editorial spaces for PUT /admin/editorial_spaces/<id>?<params>" do
    login_as 'admin'
    lambda do
      do_post :create, { :page_type => "", :page_id => "", :editorial_space => { :name => "test 1", :show_name => 1, :position => 1 } }
      do_post :create, { :page_type => 'Topic', :page_id => 1, :editorial_space => { :name => "test", :show_name => 1, :position => 1 } }
    end.should change(EditorialSpace, :count).by(2)
	  es_2 = EditorialSpace.find(:last)
	  es_1 = EditorialSpace.find(es_2.id-1)
    do_put({ :id => es_1.id, :editorial_space => { :name => "testing 123", :show_name => 0, :position => 1 } })
    do_put({ :id => es_2.id, :editorial_space => { :name => "testing 456", :show_name => 0, :position => 1 } })
    es_1.reload.name.should == "testing 123"
    es_1.page.should be_nil
    es_2.reload.name.should == "testing 456"
    es_2.page.should == Topic.find(1)
  end

  it "should delete an existing editorial space for DELETE /admin/editorial_spaces/1" do
    login_as 'admin'
    do_post :create, { :page_type => 'Topic', :page_id => 1, :editorial_space => { :name => "test", :show_name => 1, :position => 1 } }
	  es = EditorialSpace.find(:last)
    lambda do 
      do_delete({ :id => es.id })
    end.should change(EditorialSpace, :count).by(-1)
  end
end
