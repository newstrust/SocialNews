require File.dirname(__FILE__) + '/../spec_helper'

describe OpenidProfilesController do
  describe "handling GET /members/1/openid_profiles/1" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      @openid_profile = mock_openid_profile
      @member.openid_profiles.stub!(:find).and_return(@openid_profile)
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
  
    it "should find the openids requested" do
      @member.openid_profiles.should_receive(:find).with("1").and_return(@openid_profile)
      do_get
    end
  
    it "should assign the found openids for the view" do
      do_get
      assigns[:openid_profile].should equal(@openid_profile)
    end
  end

  describe "handling GET /members/1/openid_profiles/new" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      @openid_profile = mock_openid_profile
      @member.openid_profiles.stub!(:build).and_return(@openid_profile)
    end
  
    def do_get
      get :new
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should render new template" do
      do_get
      response.should render_template('new')
    end
  
    it "should create an new openid_profile" do
      @member.openid_profiles.stub!(:build).and_return(@openid_profile)
      do_get
    end
    
    it "should assign the new openid_profile for the view" do
      do_get
      assigns[:openid_profile].should equal(@openid_profile)
    end
  end

  describe "handling POST /openid_profiles" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      @openid_profile = mock_openid_profile
      @member.openid_profiles.stub!(:build).and_return(@openid_profile)
    end
    
    describe "with successful save" do
  
      def do_post
        @openid_profile.should_receive(:save).and_return(true)
        post :create, :openid_profile => {}
      end
  
      it "should create a new openid_profile" do
        @member.openid_profiles.should_receive(:build).with({}).and_return(@openid_profile)
        do_post
      end

      it "should redirect to the new openid_profile" do
        do_post
        response.should redirect_to(member_openid_profile_url(@member, @openid_profile))
      end
      
    end
    
    describe "with failed save" do
      it_should_behave_like "A Registered Member"
      def do_post
        @openid_profile.should_receive(:save).and_return(false)
        post :create, :openid_profile => {}
      end
  
      it "should re-render 'new'" do
        do_post
        response.should render_template('new')
      end
      
    end
  end

  describe "handling DELETE /members/1/openid_profiles/1" do
    it_should_behave_like "A Registered Member"
    before(:each) do
      @openid_profile = mock_model(OpenidProfile, :destroy => true)
      @member.openid_profiles.stub!(:find).and_return(@openid_profile)
    end
  
    def do_delete
      delete :destroy, :id => "1"
    end

    it "should find the openid_profile requested" do
      @member.openid_profiles.should_receive(:find).with("1").and_return(@openid_profile)
      do_delete
    end
  
    it "should call destroy on the found openid_profile" do
      @openid_profile.should_receive(:destroy)
      do_delete
    end
  
    it "should redirect to the openid_profile list" do
      do_delete
      response.should redirect_to(member_openid_profiles_url(@member))
    end
  end
end