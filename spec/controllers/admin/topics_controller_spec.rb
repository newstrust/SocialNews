require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::TopicsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  
  fixtures :all
  
  describe 'handling GET /admin/topics' do
    before(:each) do
      add_roles
      @params = {}
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
  end
  
  describe 'handling GET /admin/topics/new' do
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

  describe 'handling GET /admin/topics/some-topic' do
    before(:each) do
      add_roles
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :show, opts
    end
    
    it "should require admin access to view this action" do
      #Topic.stub!(:find).and_return(mock_model(Topic, :name => "topic", :subjects => [], :image => nil,:id => 1, :to_param => "1", :status => "list", :topic_volume => 60, :intro =>"", :allow_comments => false, :local_site => nil))
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect if the topic is not found" do
      login_as 'admin'
      Topic.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get
      response.should(redirect_to(admin_topics_path))
    end
  end
  
  describe 'handling GET /admin/topic/search.js?q=foo' do
    before(:each) do
      add_roles
      @params = { :q => 'foo' }
    end
    
    it "should return an array of results for display in the autocomplete" do
      login_as 'admin'
      Topic.stub!(:search).and_return([mock_model(Topic, :local_site => nil, :name => 'foo bar', :slug => 'foo-bar')])
      get :search, @params.merge(:format => 'js')
      response.should be_success
      response.body.should == '"foo bar||foo-bar"'
    end
  end
  
  describe 'handling GET /admin/topics/some-topic/edit' do
    before(:each) do
      add_roles
      @topic = mock_model(Topic, :id => 1, :to_param => "1", :local_site => nil)
      @topic.stub!(:subjects_to_struct).and_return([])
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require host access to view this action" do
      check_access_restriction("newshound", "host") do
        do_get @params
      end
      response.should be_success
    end

    it "should allow topic host to access edit form, even if he's not admin" do
      request.session[:member_id] = members(:trusted_member).id
      get :edit, {:id => topics(:election_reform).id}
      response.should be_success
    end

    it "should redirect if the topic is not found" do
      login_as 'admin'
      Topic.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get
      response.should(redirect_to(admin_topics_path))
    end
  end
  
  describe 'handling POST /admin/topics' do
    before(:each) do
      add_roles
      @uploaded_image = uploaded_jpeg("#{RAILS_ROOT}/spec/fixtures/rails.png")
      @params = { :topic => { :name => 'some topic', :intro => 'intro text' } }
    end
    
    def do_post(opts = {})
      post :create, opts
    end
    
    it "should require admin access to view this action" do
      login_as 'admin'
      lambda do
        lambda do
          do_post @params
        end.should change(Topic, :count).by(1)
      end.should_not change(Image, :count)
    end
    
    it "should allow an image to be uploaded." do
      login_as 'admin'
      lambda do
        lambda do
          do_post @params.merge(:image => { :uploaded_data => @uploaded_image, :credit => 'someone', :credit_url => 'http://www.google.com' })
        end.should change(Topic, :count).by(1)
      end.should change(Image, :count).by(7) # Six additional sizes are created
      assigns['topic'].image.credit.should == 'someone'
      assigns['topic'].image.credit_url.should == 'http://www.google.com'
    end

    describe "cloning local topic to national site" do
      before(:each) do
        @ls = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
        @ls.should_not be_nil
        @params.merge!(:clone_to_national => true)
        controller.stub!(:set_active_local_site).and_return { controller.instance_variable_set("@local_site", @ls) }
        login_as 'admin'
      end

      it "should clone a local site topic to national site if requested" do
        lambda do
          lambda do
            lambda do
              do_post @params
            end.should change(Topic, :count).by(2)
          end.should_not change(TopicRelation, :count)
        end.should_not change(Image, :count)
      end

      it "should clone topic relations as well" do
        lambda do
          lambda do
            lambda do
              do_post @params.merge(:topic_subjects => {:world => 1, :grouping => {:world => "world_featured"}})
            end.should change(Topic, :count).by(2)
          end.should change(TopicRelation, :count).by(2)
        end.should_not change(Image, :count)
      end

      it "should not clone images when topics are cloned" do
        lambda do
          lambda do
            do_post @params.merge(:image => { :uploaded_data => @uploaded_image, :credit => 'someone', :credit_url => 'http://www.google.com' })
          end.should change(Topic, :count).by(2)
        end.should change(Image, :count).by(7) # Six additional sizes are created
      end
    end

    describe "cloning national topic to local sites" do
      before(:each) do
        LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
        LocalSite.create(:name => "Health Local Site", :slug => "health", :subdomain => "health", :constraint_type => "Tag", :constraint_id => 10, :is_active => true)
        LocalSite.count.should == 2
        @params.merge!(:clone_to_local_sites => true)
        controller.stub!(:set_active_local_site).and_return { controller.instance_variable_set("@local_site", nil) }
        login_as 'admin'
      end

      it "should clone a national site topic to all local sites if requested" do
        lambda do
          lambda do
            lambda do
              do_post @params
            end.should change(Topic, :count).by(3)
          end.should_not change(TopicRelation, :count)
        end.should_not change(Image, :count)
      end

      it "should clone topic relations as well" do
        lambda do
          lambda do
            lambda do
              do_post @params.merge(:topic_subjects => {:world => 1, :grouping => {:world => "world_featured"}})
            end.should change(Topic, :count).by(3)
          end.should change(TopicRelation, :count).by(3)
        end.should_not change(Image, :count)
      end

      it "should not clone images when topics are cloned" do
        lambda do
          lambda do
            do_post @params.merge(:image => { :uploaded_data => @uploaded_image, :credit => 'someone', :credit_url => 'http://www.google.com' })
          end.should change(Topic, :count).by(3)
        end.should change(Image, :count).by(7) # Six additional sizes are created
      end
    end
  end
  
  describe 'handling PUT /admin/topics/some-topic' do
    before(:each) do
      add_roles
      # removed silly topic stubbing acrobatics and stuffed them in the relevant spec below
      @params = { :id => 1, :topic => { :name => 'some topic', :intro => 'intro text' } }
    end
    
    def do_put(opts = {})
      put :update, opts
    end
    
    it "should require admin access to view this action" do
      # use fixture data, not these silly stubs!
      @topic = topics(:election_reform)
      
      login_as 'editor'
      put :update, :id => @topic.id, :topic => {:name => "New Name"}
      response.response_code.should_not == 200
      response.body =~ /denied/

      login_as 'admin'
      put :update, :id => @topic.id, :topic => {:name => "New Name"}
      response.flash[:notice].should_not be_nil
      response.should(redirect_to(edit_admin_topic_path(@topic)))
    end
    
    it "should redirect and display an error on a failed update" do
      @topic = mock_model(Topic, :name => "mock_topic", :id => 1, :to_param => "1", :local_site => nil)
      Topic.stub!(:find).and_return(@topic)
      @topic.stub!(:update_attributes).and_return(true)
      
      login_as 'admin'
      @topic.stub!(:update_attributes).and_return(false)
      do_put @params
      response.flash[:notice].should be_nil
      response.should be_success
    end

    it "should not update a topic if there exists another topic/subject with the same name"
    it "should merge the topic with an existing tag when the topic's name is changed to the name of the existing tag"
  end
  
  describe "handling DELETE /admin/topics/some-topic/destroy_image" do
    before(:each) do
      add_roles
      @image = mock_model(Image, :id => 1, :to_param => "1")
      @topic = mock_model(Topic, :id => 1, :to_param => "1", :image => @image, :local_site => nil)
      Topic.stub!(:find).and_return(@topic)
      @topic.image.stub!(:destroy).and_return(true)
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
      response.should(redirect_to(edit_admin_topic_path(@topic)))
    end
    
    it "should redirect if the image cannot be deleted" do
      login_as 'admin'
      @topic.image.stub!(:destroy).and_return(false)
      do_delete @params
      response.flash[:error].should_not be_nil
      response.should(redirect_to(edit_admin_topic_path(@topic)))
    end
  end
  
  describe 'handling DELETE /admin/topics/some-topic' do
    before(:each) do
      add_roles
      te = tags(:environment)
      @topic = mock_model(Topic, :id => 1, :tag => te, :tag_id => te.id, :to_param => "1", :local_site => nil)
      Topic.stub!(:find).and_return(@topic)
      @topic.stub!(:destroy).and_return(true)
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
      response.should(redirect_to(admin_topics_path))
    end
    
    it "should redirect if the topic could not be deleted" do
      @topic.stub!(:destroy).and_return(false)
      login_as 'admin'
      do_delete
      response.flash[:error].should_not be_nil
      response.should(redirect_to(admin_topics_path))
    end
  end
end
