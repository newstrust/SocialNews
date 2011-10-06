require File.dirname(__FILE__) + '/../../spec_helper'

module CommentControllerHelper
  def login_as_member(member = nil)
    min_v = SocialNewsConfig["min_validation_level_for_comments"]
    @member = member || mock_member
    Member.stub!(:find_by_id).and_return(@member)
    Member.stub!(:validation_level).and_return(min_v)
    @member.stub!(:process_guest_actions).and_return(nil)
    request.session[:member_id] = @member.id
    @member
  end

  def allow_edits(member, comment)
    member.stub!(:has_role?).and_return(true)
    comment.stub!(:can_be_edited_by?).and_return(true)
  end
end

describe Discussions::CommentsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper
  include CommentControllerHelper

  fixtures :all

  describe "handling GET /comments" do

    before(:each) do
      @comment = mock_model(Comment)
      Comment.stub!(:find).and_return([@comment])
    end

    def do_get
      get :index
    end

    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should render index template" do
      do_get
      response.should render_template('index')
    end
  end
  describe "handling GET /comments/1" do
    it_should_behave_like "A valid session"
    before(:each) do
      @comment = mock_model(Comment, { :ancestors => [mock_comment] })
      Comment.stub!(:find).and_return(@comment)
    end

    def do_get
      get :show, :id => "1"
    end

    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should render show template" do
      do_get
      response.should render_template('show')
    end

    it "should find the comment requested" do
      do_get
    end

    it "should assign the found comment for the view" do

      do_get
      assigns[:comment].should equal(@comment)
    end
  end

  describe "handling GET /comments/new" do
    before(:each) do
      add_roles
      @comment = mock_model(Comment, :id => "1", :to_param => '1')
    end

    def use_admin
      Role.stub!(:find).and_return([@admin_role])
      login_as 'admin'
      @admin.stub_association!(:comments, :create => true, :build => mock_comment, :find => mock_comment)
      @admin.comments.stub!(:build).and_return(@comment)
    end

    def do_get
      get :new
    end

    it "should be successful" do
      use_admin
      do_get
      response.should be_success
    end

    it "should render new template" do
      use_admin
      do_get
      response.should render_template('new')
    end

    it "should create an new comment" do
      use_admin
      @admin.comments.should_receive(:build).and_return(@comment)
      do_get
    end

    it "should not save the new comment" do
      use_admin
      @comment.should_not_receive(:save)
      do_get
    end

    it "should assign the new comment for the view" do
      use_admin
      do_get
      assigns[:comment].should equal(@comment)
    end

    it "should deny access to anyone who doesn't have the required role." do
      do_get
      response.should redirect_to(new_sessions_path)
    end
  end

  describe "handling GET /comments/1/reply" do
    before(:each) do
      @parent  = mock_model(Comment, :id => "1", :to_param => '1', :commentable_type => 'Source', :commentable_id => '1')
      @parent.stub_association!(:children)
      @parent.children.stub!(:build).and_return(@comment)
      Comment.stub!(:find).and_return(@parent)
      @member = login_as_member
    end

    def do_get
      get :reply, :id => 1
    end

    it "should render new template" do
      @comment = mock_comment(:id => "2", :to_param => '2', :parent_id => '1', :commentable_type= => 'Source', :commentable_id= => '1')
      @member.comments.should_receive(:build).and_return(@comment)
      do_get
      response.should be_success
      response.should render_template('reply')
    end

    it "should create an new comment" do
      @comment = mock_comment(:id => "2", :to_param => '2', :parent_id => '1', :commentable_type= => 'Source', :commentable_id= => '1')
      @member.comments.should_receive(:build).and_return(@comment)
      do_get
    end

    it "should assign the parent for the view" do
      @comment = mock_comment(:id => "2", :to_param => '2', :parent_id => '1', :commentable_type= => 'Source', :commentable_id= => '1')
      @member.comments.should_receive(:build).and_return(@comment)
      do_get
      assigns[:parent].should equal(@parent)
    end
  end

  describe "handling GET /comments/1/edit" do
   it_should_behave_like "A valid session"
    before(:each) do
      @comment = mock_model(Comment)
      @member = login_as_member
      allow_edits(@member, @comment)
      Comment.stub!(:find).and_return(@comment)
    end

    def do_get
      get :edit, :id => "1"
    end

    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should render edit template" do
      do_get
      response.should render_template('edit')
    end

    it "should find the comment requested" do
      Comment.stub!(:find).and_return(@comment)
      Comment.should_receive(:find).and_return(@comment)
      do_get
    end

    it "should assign the found Comment for the view" do
      do_get
      assigns[:comment].should equal(@comment)
    end

    it "should only allow members with access to edit the comment" do
      @comment.stub!(:can_be_edited_by?).and_return(false)
      do_get
      response.flash[:error].should_not be_nil
      response.should redirect_to(discussions_comments_path)
    end
  end
  describe "handling POST /comments when notifying users" do
    fixtures :all

    before(:each) do
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      @member = login_as_member(members(:heavysixer))
    end

    it "should notify staff when a new comment is created" do
      @t = Topic.first
      @t.update_attribute(:allow_comments,true)
      @t.add_host(members(:heavysixer))
      @comment = Comment.create(:title => 'new reply', :body => 'foo', :commentable_id =>@t, :commentable_type => 'Topic', :member_id => @member.id)
      @member.comments.stub!(:build).and_return(@comment)
      @comment.should_receive(:save).and_return(true)
      post :create, :comment => { :body => 'foo', :commentable_type => 'Source', :commentable_id => 2 }

      ActionMailer::Base.deliveries.size.should == 1
      ActionMailer::Base.deliveries.first.to.include?(members(:heavysixer).email)
      ActionMailer::Base.deliveries.first.subject.should =~ /New #{@t.class.to_s.downcase} comment on #{SocialNewsConfig["app"]["name"]}/
    end

    it "should send a notification to parent member when they receive replies" do
      @m = members(:trusted_member)
      @m.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @parent = @m.comments.create(:body => 'My comment')

      @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @comment = Comment.new(:title => 'new reply', :body => 'foo', :member_id => @member.id)
      @comment.initial_ancestor_id = @parent.id
      @comment.save
      @comment.nest_inside(@parent.id)
      @member.comments.stub!(:build).and_return(@comment)
      @comment.should_receive(:commentable_type).at_least(:once).and_return('Source')
      @comment.should_receive(:commentable_id).at_least(:once).and_return(2)
      @comment.should_receive(:save).and_return(true)
      post :create, :comment => { :commentable_type => 'Source', :commentable_id => 2, :body => "dummy comment" }
      ActionMailer::Base.deliveries.size.should == 2
      ActionMailer::Base.deliveries.last.to.should eql([@parent.member.email])
    end
  end

  describe "handling POST /comments" do
    before(:each) do
      @comment = mock_model(Comment, :id => "1", :to_param => '1', :commentable_type => 'Source')
      @member = login_as_member
      @member.comments.stub!(:build).and_return(@comment)
    end

    describe "with successful save" do

      def do_post
        @comment.should_receive(:commentable_type).at_least(:once).and_return('Source')
        @comment.should_receive(:commentable_id).and_return(2)
        @comment.should_receive(:save).and_return(true)
        post :create, :comment => { :commentable_type => 'Source', :commentable_id => 2, :body => "dummy comment" }
      end

      it "should create a new comment" do
        @member.comments.should_receive(:build).with({ "commentable_type"=>"Source", "commentable_id"=>2, "body" => "dummy comment" }).and_return(@comment)
        do_post
      end

      it "should redirect to the new comment" do
        @member.comments.stub!(:save).and_return(true)
        do_post
        response.should redirect_to("http://test.host/sources/washington_post")
      end

    end

    describe "with failed save" do

      def do_post
        post :create, :comment => { :body => "dummy comment" }
      end

      it "should re-render 'new'" do
        @comment.should_receive(:save).and_return(false)
        do_post
        response.should render_template('new')
      end

    end
  end

  describe "handling PUT /comments/1" do
    fixtures :all
    before(:each) do
      @member = login_as_member(members(:heavysixer))
      @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @comment =  @member.comments.create(:body => 'my comment')
      Comment.stub!(:find).and_return(@comment)
    end

    describe "with successful update" do
      def do_put(opts = {})
        put :update, :id => "1", :comment => { :body => 'foo' }.merge(opts)
      end

      it "should update the found comment" do
        @comment.last_edited_by_id.should be_nil
        do_put
        assigns['comment'].should equal(@comment)
        @comment.reload.last_edited_by_id.should == @member.id
      end

      it "should assign the found comment for the view" do
        do_put
        assigns(:comment).should equal(@comment)
      end

      it "should redirect to the comment" do
        do_put
        response.should redirect_to(discussions_comment_url(@comment.id))
      end
    end

    describe "with failed update" do
      def do_put
        @comment.stub!(:update_attributes).and_return(false)
        put :update, :id => "1"
      end

      it "should re-render 'edit'" do
        do_put
        response.should render_template('edit')
      end
    end
  end

  describe "handling GET  /comments/1/confirm_delete" do
    fixtures :all
    before(:each) do
      @member = login_as_member(members(:heavysixer))
      @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @comment = @member.comments.create(:body => 'my comment')
    end

    def do_get(opts = {})
      get :confirm_delete, { :id => @comment }.merge(opts)
    end

    it "should make a member confirm they want to delete a comment" do
      do_get
      response.should be_success
      response.flash[:notice].should_not be_nil
    end

    it "should redirect if the comment cannot be found" do
      do_get(:id => nil)
      response.should redirect_to(discussions_comments_url)
    end
  end

  describe "handling DELETE /comments/1" do
    fixtures :all
    before(:each) do
      @member = login_as_member(members(:heavysixer))
      @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @comment = @member.comments.create(:body => 'my comment')
      @comment.stub!(:update_attribute).and_return(true)
      allow_edits(@member, @comment)
    end

    def do_delete
      delete :destroy, :id => @comment.id
    end

    it "should redirect when the comment is not found" do
      Comment.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_delete
      response.flash[:error].should_not be_nil
      response.should redirect_to(discussions_comments_path)
    end

    it "should hide but not destroy the found comment" do
      lambda do
        do_delete
      end.should_not change(Comment, :count)
      assigns("comment").hidden.should be_true
      response.flash[:notice].should_not be_nil
      response.should redirect_to(discussions_comment_path(@comment.root))
    end
  end
end
