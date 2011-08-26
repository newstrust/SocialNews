require File.dirname(__FILE__) + '/../spec_helper'

describe StoriesController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  #include CacheTestsHelper

  fixtures :all
  
  before(:each) do
    @story = stories(:legacy_story)
    @story_4 = stories(:story_4)
    MetadataFetcher::Daylife.stub!(:get_metadata).and_return(nil)
    MetadataFetcher::Digg.stub!(:get_metadata).and_return(nil)
    MetadataFetcher::Tweetmeme.stub!(:get_metadata).and_return(nil)
    StoryAutoPopulator.stub!(:update_story_metadata_from_apis).and_return({})
    StoryAutoPopulator.should_receive(:fetch_story_content).any_number_of_times.and_return {|s| s.body = "Dummy body" }
    StoryAutoPopulator.should_receive(:set_story_title).any_number_of_times.and_return { |s| s.title = "Dummy title!" }
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

  it "no guests submits" do
    lambda do
      post :post, {:url => @story_4.url + "/new_url_2"}
    end.should change(Story, :count).by(0)
    response.should redirect_to(new_sessions_path)
  end

  describe "story posts" do
    before(:each) do
      spec_login_as(members(:legacy_member))
    end

    it "should save story to db if story url does not exist in the db" do
      lambda do
        do_post(:create, {:url => @story_4.url + "/new_url", :format => "js"})
      end.should change(Story, :count).by(1)
      response.should be_success
      json_response = ActiveSupport::JSON.decode(response.body)
      json_response["id"].should_not be_nil
      json_response["validation_errors"].should be_blank
    end

    it "should not change story count if story url exists in the db" do
      lambda do
        do_post(:create, {:url => @story_4.url, :format => "js"})
      end.should change(Story, :count).by(0)
      response.should be_success
    end

    it "should return error with bad urls" do
      lambda do
        do_post(:create, {:url => "fail fail fail!", :format => "js"})
      end.should change(Story, :count).by(0)
      response.should be_success
      json_response = ActiveSupport::JSON.decode(response.body)
      json_response["validation_errors"].should_not be_blank
    end

    it "should add local site tagging if posted from a local site" do
      ls = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
      controller.stub!(:set_active_local_site).and_return { controller.instance_variable_set("@local_site", ls) }
      new_url = @story_4.url + "/new_url_3"
      lambda do
        lambda do
          do_post(:create, {:url => new_url, :format => "js"})
        end.should change(Story, :count).by(1)
      end.should change(Tagging, :count)
      s = Story.find_by_url(new_url)
      s.tags.include?(ls.constraint).should == true
    end

    describe "should set editorial priority to" do
      def verify_ep(ml, ep)
        m = members(:legacy_member)
        m.validation_level = ml
        m.save!
        do_post(:create, {:url => @story_4.url + "/new_url", :format => "js"})
        json_response = ActiveSupport::JSON.decode(response.body)
        s = Story.find(json_response["id"].to_i)
        s.editorial_priority.should == ep
      end

      it "member level for members with validation level < 3" do
        verify_ep(2, 2)
      end

      it "3 for members with validation level > 3" do
        verify_ep(5, 3)
      end

      it "1 for guest submissions"
    end
  end

  describe "legacy button/bookmarklet submits" do
    before(:each) do 
      @m = members(:legacy_member)
      spec_login_as(@m)
    end

    it "should popup toolbar if story already exists in the db" do
      lambda do
        post :post, {:url => @story_4.url}
      end.should change(Story, :count).by(0)
      response.should redirect_to(toolbar_story_path(@story_4, :go => :review, :ref => :nav_dup))
    end

    it "should popup toolbar with the review form open if story already exists in the db, is vetted and a member is logged in" do
      # Doesn't work in rails 2.3 anymore because :reviews_count is a read_only attribute since it is a counter-cache
      # @story_4.update_attributes({:edited_by_member_id => @m.id, :reviews_count => 5})
      Story.update_all("edited_by_member_id = #{@m.id}, reviews_count = 5", :id => @story_4.id)
      lambda do
        post :post, {:url => @story_4.url}
      end.should change(Story, :count).by(0)
      response.should redirect_to(toolbar_story_path(@story_4, :go => :review, :ref => :nav_dup))
    end

    it "should popup toolbar with the edit form open if story already exists in the db, is unvetted and a member is logged in" do
      # Doesn't work in rails 2.3 anymore because :reviews_count is a read_only attribute since it is a counter-cache
      #@story_4.update_attributes({:edited_by_member_id => nil, :reviews_count => 0})
      Story.update_all("edited_by_member_id = NULL, reviews_count = 0", :id => @story_4.id)
      lambda do
        post :post, {:url => @story_4.url}
      end.should change(Story, :count).by(0)
      response.should redirect_to(toolbar_story_path(@story_4, :go => :edit, :ref => :nav_dup))
    end

    it "should save story to db and popup toolbar with review form for guests if story url does not exist in the db" do
      new_url = @story_4.url + "/new_url"
      lambda do
        post :post, {:url => new_url}
      end.should change(Story, :count).by(1)
      s = Story.find_by_url(new_url)
      s.title.should == "Dummy title!"
      response.should redirect_to(toolbar_story_path(s, :go => :edit, :ref => :nav))
    end

    it "should save story to db and popup toolbar with edit form for members if story url does not exist in the db" do
      new_url = @story_4.url + "/new_url"
      lambda do
        post :post, {:url => new_url}
      end.should change(Story, :count).by(1)
      s = Story.find_by_url(new_url)
      s.title.should == "Dummy title!"
      response.should redirect_to(toolbar_story_path(s, :go => :edit, :ref => :nav))
    end

    describe "should not clobber info from button/bookmarklet params" do
      it "should leave title unchanged" do
        new_url = @story_4.url + "/new_url_2"
        lambda do
          post :post, {:url => new_url, :title => "Use this title now"}
        end.should change(Story, :count).by(1)
        s = Story.find_by_url(new_url)
        s.title.should == "Use this title now"
        response.should redirect_to(toolbar_story_path(s, :go => :edit, :ref => :nav))
      end
    end
  end

  describe "story create" do
    before(:each) do
      m = members(:legacy_member)
      spec_login_as(m)
      @new_story = stories(:story_2)
      @new_story.id = nil
      @new_story.legacy_id = nil
      @new_story.submitted_by_id = m.id
      @new_story.journalist_names = ""
      @new_story.content_type="Article"
      @new_story.excerpt="Dummy Excerpt"
      @new_story.taggings = [Tagging.new(:tag => tags(:environment), :member_id => m.id)]
      @new_story.authorships = [Authorship.new(:source => Source.find_by_id(@new_story.primary_source_id))]
      @new_story_attrs = @new_story.attributes
      @new_story_attrs.merge!({:taggings_attributes => @new_story.taggings.collect { |t| t.attributes }, :authorships_attributes => @new_story.authorships.collect { |t| t.attributes }})
    end
  end
  
  describe "story views" do
    it "should log page views once per session" do
      @story.page_views.should be_empty
      get :show, :id => @story.id
      @story.reload.page_views.length.should eql(1)
      get :show, :id => @story.id
      @story.reload.page_views.length.should eql(1)
    end
  
    it "should get slated for a rating recalc after being viewed" do
      ProcessJob.find(:first, :conditions => {
        :processable_id => @story.id,
        :processable_type => @story.class.name}).should be_nil
      
      get :show, :id => @story.id
      
      ProcessJob.find(:first, :conditions => {
        :processable_id => @story.id,
        :processable_type => @story.class.name}).should_not be_nil
    end
    
    it "should redirect from hidden stories" do
      s = stories(:unreviewed_story)
      get :show, :id => s.id
      response.should be_success
      
      # now hide the story
      s.update_attributes(:status => "hide")
      
      get :show, :id => s.id
      response.response_code.should == 403
    end

    it "should allow admins to view hidden stories" do
      # now hide the story
      s = stories(:unreviewed_story)
      s.update_attributes(:status => "hide")
      add_roles # guess this is necessary to test admin login?
      login_as 'admin'
      get :show, :id => s.id
      response.should be_success
    end

    it "should allow non-admin submitters to view their stories, even if pending/hidden" do
      m = members(:trusted_member)
      s = stories(:unreviewed_story)
      s.update_attributes(:status => "hide")
      s.update_attributes(:submitted_by_id => m.id)
      spec_login_as(m)
      get :show, :id => stories(:unreviewed_story).id
      response.should be_success
    end
  end
  
  describe "story edits" do
    before(:each) do
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      @story = stories(:legacy_story)
    end

    it "should cruddily update authorships association" do
      spec_login_as(members(:legacy_member))
      
      # add an authorship
      lambda do
        post :update, :id => @story.id,
          "story"=>{"authorships_attributes"=>[{"id"=>"1", "source_id"=>"1"}, {"source_id"=>"2"}], "excerpt" => "Some excerpt"}
      end.should change(stories(:legacy_story).reload.authorships, :size).by(1)
      
      # remove the original one
      new_authorship_id = @story.authorship_ids.last
      lambda do
        post :update, :id => @story.id,
          "story"=>{"authorships_attributes"=>[
            {"id"=>"1", "source_id"=>"1", "should_destroy"=>"true"},
            {"id"=>new_authorship_id.to_s, "source_id"=>"2"}]}
      end.should change(@story.reload.authorships, :size).by(-1)
    end

    it "should create a new pending source if user typed unknown source name into batch_autocomplete" do
      spec_login_as(members(:legacy_member))
      
      unknown_source_name = "Crazy Source u never heard of"
      
      lambda do
        post :update, :id => @story.id,
          "story"=>{"authorships_attributes"=>[{"id"=>"1", "source_id"=>"1"}, {"name"=>unknown_source_name}], "excerpt" => "Some excerpt"}
      end.should change(Source, :count).by(1)
      
      Source.find_by_name(unknown_source_name).status.should == "pending"
    end
    
    it "should record who last edited & when" do
      pending("need to better understand how MockMember works")
    end

    describe "email notifications" do
      before(:each) do
        @m = members(:heavysixer)
        @story.submitted_by_member = @m 
        @story.edited_by_member = @m
        @story.save!
        spec_login_as(members(:legacy_member))
      end

      edit_email_id = SocialNewsConfig["email_addrs"]["edits"]

      it "should go out to #{edit_email_id}" do
        post :update, :id => @story.id, :story => {"excerpt" => "New Excerpt"}
        ActionMailer::Base.deliveries.size.should be(1)
        ActionMailer::Base.deliveries[0].to.first.should == edit_email_id
      end

      it "should not go out to non-staff submitters if a new person edits the story" do
        post :update, :id => @story.id, :story => {"excerpt" => "New Excerpt"}
        ActionMailer::Base.deliveries.size.should be(1)
      end

      it "should go out to staff submitters if a new person edits the story" do
        groups(:admins).add_member(@m)
        post :update, :id => @story.id, :story => {"excerpt" => "New Excerpt"}
        ActionMailer::Base.deliveries.size.should be(2)
        ActionMailer::Base.deliveries[0].to.first.should == @m.email
      end

      it "should not go out to non-staff previous editor if a new person edits the story" do
        post :update, :id => @story.id, :story => {"excerpt" => "New Excerpt"}
        ActionMailer::Base.deliveries.size.should be(1)
      end

      it "should go out to non-staff previous editor if a new person edits the story" do
        groups(:admins).add_member(@m)
        post :update, :id => @story.id, :story => {"excerpt" => "New Excerpt"}
        ActionMailer::Base.deliveries.size.should be(2)
        ActionMailer::Base.deliveries[0].to.first.should == @m.email
      end
    end

    it "should set story status to list if its status is queue" do
      spec_login_as(members(:legacy_member))
      @story.status = Story::QUEUE
      @story.save!
      @story.reload.status.should == Story::QUEUE
      post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt"}
      @story.reload.status.should == Story::LIST
    end

    describe "from local site" do
      before(:each) do
        @story.taggings.delete_all
        @story.tags.count.should == 0
        @ls = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
        controller.stub!(:set_active_local_site).and_return { controller.instance_variable_set("@local_site", @ls) }
        spec_login_as(members(:legacy_member))
      end

      it "should add local site tagging to an existing pending story" do
        @story.update_attributes({:status => Story::PENDING})
        lambda do
          lambda do
            do_post(:update, :id => @story.id, "story" => {"url" => @story.url + "_new"})
          end.should change(Story, :count).by(0)
        end.should change(Tagging, :count)
        @story.reload.tags.include?(@ls.constraint).should == true
      end

      it "should not add local site tagging to an existing listed story" do
        @story.update_attributes({:status => Story::LIST})
        lambda do
          lambda do
            do_post(:update, :id => @story.id, "story" => {"url" => @story.url + "_new"})
          end.should change(Story, :count).by(0)
        end.should change(Tagging, :count).by(0)
        @story.reload.tags.include?(@ls.constraint).should == false
      end
    end

    describe "story type tests" do
      before(:each) do
        spec_login_as(members(:legacy_member))
        @story.status = Story::QUEUE
        @story.save!
        @story.reload.status.should == Story::QUEUE
        @orig_type = @story.story_type
      end

# SSS: No longer valid!
#
#      it "should set not save if missing a story type" do
#        post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt", "story_type" =>""}
#        @story.reload
#        @story.status.should == Story::QUEUE
#        @story.story_type.should == @orig_type
#      end

      it "should set process condensed story type properly" do
        post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt", "story_type_condensed" => "other"}
        @story.reload
        @story.status.should == Story::LIST
        @story.story_type.should == "other"
      end

      it "should ignore expanded story type if it is not visible to the member because of preferred edit form version" do
        m = members(:legacy_member)
        m.update_attribute(:preferred_edit_form_version, "quick")
        post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt", "story_type_expanded" => "editorial", "story_type_condensed" => @story.story_type_condensed}
        @story.reload
        @story.status.should == Story::LIST
        @story.story_type.should_not == "editorial"
      end

      it "should overwrite expanded story type if preferred edit form version is short or quick" do
        m = members(:legacy_member)
        m.update_attribute(:preferred_edit_form_version, "quick")
        post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt", "story_type_condensed" => @story.story_type_condensed}
        @story.reload
        @story.status.should == Story::LIST
        @story.story_type.should_not == @orig_type
        @story.story_type.should == "news"
      end

      it "should set expanded story type if it is visible to the member because of preferred edit form version" do
        m = members(:legacy_member)
        m.update_attribute(:preferred_edit_form_version, "full")
        post :update, :id => @story.id, "story"=>{"excerpt" => "Some excerpt", "story_type_expanded" => "editorial"}
        @story.reload
        @story.status.should == Story::LIST
        @story.story_type.should == "editorial"
      end
    end
  end
  
  describe "story saves" do
    it "should allow saving & unsaving" do
      pending "need to understand MockMember"
    end
  end
  
  describe "story listing" do
    it 'should return 404 for /stories' do
      do_get
      response.response_code.should == 404
    end

    it 'should return 404 for /stories.xml' do
      do_get("index", :format => "xml")
      response.response_code.should == 404
    end

    it 'should return 404 for /stories.js' do
      do_get("index", :format => "js")
      response.response_code.should == 404
    end

    it 'should not return 404 for /stories/most_recent' do
      do_get("index", :listing_type => "most_recent")
      response.response_code.should == 200
    end

    describe "rss feeds" do
      it "should render /stories/most_recent.xml" do
        do_get("index", :listing_type => "most_recent", :format => "xml")
        response.response_code.should == 200
        response.should render_template('rss_feeds/stories.rss.builder')
      end
    end

    it 'should be tested some more'

#    it 'should not page cache html listings' do
#      ActionController::Base.perform_caching = true
#      requesting {get :index}.should_not be_cached
#      ActionController::Base.perform_caching = false
#    end
#
#    it 'should page cache json listings' do
#      ActionController::Base.perform_caching = true
#      requesting {get :index, :listing_type => "most_recent", :format => 'json'}.should be_cached
#      ActionController::Base.perform_caching = false
#    end
  end

  describe "toolbar" do
    it "should log a story click" do
      m = members(:legacy_member)
      spec_login_as(m)
      s = stories(:story_4)
      sc = StoryClick.find(:all, :conditions => {:story_id => s.id, :data => m.id})
      sc.each { |x| x.delete } if sc

      lambda do
        get :toolbar, :id => s.id
      end.should change(StoryClick, :count).by(1)

      lambda do
        get :toolbar, :id => s.id
      end.should change(StoryClick, :count).by(0)
    end
  end

  describe "rss feeds" do
    it "should generate feeds for stories/most_recent.xml" do
      get :stories, :listing_type => :most_recent
      response.status.should =~ /302/
    end
  end
end
