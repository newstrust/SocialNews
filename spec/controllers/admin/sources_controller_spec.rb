require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::SourcesController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :sources
  
  describe 'handling GET /admin/sources' do
    before(:each) do
      add_roles
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
    end
  end
  
  describe 'handling GET /admin/sources/pending' do
    before(:each) do
      add_roles
      @params = {}
    end

    def do_get(opts = {})
      get :pending, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
  end
  
  describe 'handling GET /admin/sources/listed' do
    before(:each) do
      add_roles
      @params = {}
    end

    def do_get(opts = {})
      get :listed, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
  end
  
  describe 'handling GET /admin/sources/new' do
    before(:each) do
      add_roles
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :new, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
    end
  end

  describe 'handling GET /admin/sources/some-source' do
    before(:each) do
      add_roles
      @params = { :id => 1 }
      @source = mock_model(Source, :id => 1, :name => "Mock Source", :to_param => "1", :image => nil)
    end
    
    def do_get(opts = {})
      get :show, opts
    end
    
    it "should require admin access to view this action" do
      Source.stub!(:find).and_return(@source)
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect if the source is not found" do
      login_as 'admin'
      Source.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get
      response.should(redirect_to(admin_sources_path))
    end
  end
  
  describe 'handling GET /admin/sources/some-source/edit' do
    before(:each) do
      add_roles
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require admin access to view this action" do
      @source = sources(:legacy_source)
      Source.stub!(:find).and_return(@source)
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end

    it "should redirect if the source is not found" do
      login_as 'admin'
      Source.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get
      response.should(redirect_to(admin_sources_path))
    end
  end
  
  describe 'handling GET /admin/sources/search.js?q=foo' do
    before(:each) do
      add_roles
      @params = { :q => 'foo' }
    end
    
    it "should return an array of results for display in the autocomplete" do
      login_as 'admin'
      Source.stub!(:search).and_return([mock_model(Source, :name => 'foo bar', :slug => 'foo-bar', :status => 'list', :id => 1549 )])
      get :search, @params.merge(:format => 'js')
      response.should be_success
      response.body.should == '"foo bar|list|foo-bar|1549"'
    end
  end
  
  describe 'handling POST /admin/sources' do
    before(:each) do
      add_roles
      @uploaded_image = uploaded_jpeg("#{RAILS_ROOT}/spec/fixtures/rails.png")
      @params = { :source => { :name => 'some source' } }
    end
    
    def do_post(opts = {})
      post :create, opts
    end
    
    it "should require admin access to view this action" do
      login_as 'admin'
      lambda do
        lambda do
          do_post @params
        end.should change(Source, :count).by(1)
      end.should_not change(Image, :count)
    end
    
    it "should render the new template when saving fails" do
      login_as 'admin'
      @source = mock_model(Source, :save => false )
      Source.stub!(:new).and_return(@source)
      do_post @params
      response.should be_success
      response.should render_template('new')
    end

    it "should default to other source medium when that info is missing" do
      login_as 'admin'
      lambda do
        do_post @params
      end.should change(Source, :count).by(1)
      s = Source.find(:last)
      response.should(redirect_to(admin_source_path(s)))
      s.source_media.first.medium.should == SourceMedium::OTHER
    end

    it "should allow an image to be uploaded." do
      login_as 'admin'
      lambda do
        lambda do
          do_post @params.merge(:image => { :uploaded_data => @uploaded_image, :credit => 'someone', :credit_url => 'http://www.google.com' })
        end.should change(Source, :count).by(1)
      end.should change(Image, :count).by(7) # Six additional sizes are created

      assigns['source'].edited_by_member_id.should == 11 # mock id from spec_helpers.rb
      assigns['source'].last_edited_at.should_not be_nil;
      assigns['source'].image.credit.should == 'someone'
      assigns['source'].image.credit_url.should == 'http://www.google.com'
    end
  end
  
  describe 'handling PUT /admin/sources/some-source' do
    before(:each) do
      add_roles
      @source = mock_model(Source, :id => 1, :name => "Mock Source", :to_param => "1")
      Source.stub!(:find).and_return(@source)
      @source.stub!(:update_attributes).and_return(true)
      @params = { :id => 1, :source => { :name => 'some source' } }
    end
    
    def do_put(opts = {})
      put :update, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_put @params
      end
      response.flash[:notice].should_not be_nil
      response.should(redirect_to(edit_admin_source_path(@source)))
    end
    
    it "should redirect and display an error on a failed update" do
      login_as 'admin'
      @source.stub!(:update_attributes).and_return(false)
      do_put @params
      response.flash[:notice].should be_nil
      response.should be_success
    end
  end
  
  describe "handling DELETE /admin/sources/some-source/destroy_image" do
    before(:each) do
      add_roles
      @image = mock_model(Image, :id => 1, :to_param => "1")
      @source = mock_model(Source, :id => 1, :name => "Mock Source", :to_param => "1", :image => @image)
      Source.stub!(:find).and_return(@source)
      @source.image.stub!(:destroy).and_return(true)
      @params = { :id => 1 }
    end

    def do_delete(opts = {})
      delete :destroy_image, opts
    end
    
    it "should delete the associated image if possible" do
      should_be_admin_only do
        do_delete @params
      end
      response.flash[:notice].should_not be_nil
      response.should(redirect_to(edit_admin_source_path(@source)))
    end
    
    it "should redirect if the image cannot be deleted" do
      login_as 'admin'
      @source.image.stub!(:destroy).and_return(false)
      do_delete @params
      response.flash[:error].should_not be_nil
      response.should(redirect_to(edit_admin_source_path(@source)))
    end
  end
  
  describe 'handling DELETE /admin/sources/some-source' do
    before(:each) do
      add_roles
      @source = mock_model(Source, :id => 1, :name => "Mock Source", :to_param => "1")
      Source.stub!(:find).and_return(@source)
      @source.stub!(:destroy).and_return(true)
      @params = { :id => 1 }
    end
    
    def do_delete(opts = {})
      delete :destroy, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_delete @params
      end
      response.flash[:notice].should_not be_nil
      response.should(redirect_to(admin_sources_path))
    end
    
    it "should redirect if the source could not be deleted" do
      @source.stub!(:destroy).and_return(false)
      login_as 'admin'
      do_delete
      response.flash[:error].should_not be_nil
      response.should(redirect_to(admin_sources_path))
    end
  end
end
