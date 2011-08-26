require File.dirname(__FILE__) + '/../spec_helper'

describe OpenidProfilesHelper, "when making a request to an openid server" do
  include OpenIdAuthentication
  include OpenidProfilesHelper
  before(:each) do  
    stub!(:render).and_return(true)
    stub!(:using_open_id?).and_return(true)
  end
  
  it "should use an openid_authentication and bypass the normal account creation process" do
    stub!(:authenticate_with_open_id).and_return 
    params[:openid_url] = 'https://myname.openid.com'
    create
  end
  
  it "should raise an error if an openid url is not supplied" do
    create
    puts flash[:error]
    flash[:error].should =~ /is not an OpenID URL/
  end

  it "should throw an error if the normal create method is not defined in the controller" do
    stub!(:using_open_id?).and_return(false)
    # Overwrite the throw mechanism because it is unclear how to "catch" in an rspec test.
    self.stub!(:normal_create).and_raise(NameError)
    lambda {create}.should raise_error(NameError)
  end
end

describe OpenidProfilesHelper, "when handling the response from a openid server" do
  include OpenIdAuthentication
  include OpenidProfilesHelper
  it_should_behave_like "A valid response from an openid provider"
  fixtures :all
  before(:each) do
    
    # Stub out these controller methods since we are working outside of the scope of the controller.
    stub!(:current_member=).and_return(mock_member)
    stub!(:redirect_back_or_default).and_return(true)
    stub!(:render).and_return(true)
    
    @result = mock('Result', :successful? => true)
    @identity_url = 'https://myid.openid.com/'
    @registration = mock_sreg_response
    @creating = lambda{ create }
  end
  
  it "should create an account using the openid parameters" do
    stub!(:authenticate_with_open_id).and_yield(@result, @identity_url, @registration)
    @creating.should change(Member, :count).by(1)
    @completed_member.should_not be_nil
    member = Member.find_by_email(@registration["email"])
    member.name.should == @registration["fullname"]
    member.openid_profiles.first.openid_url.should == @identity_url
  end
  
  it "should create a new openid_profile after creating the member" do
    stub!(:authenticate_with_open_id).and_yield(@result, @identity_url, @registration)
    @creating.should change(OpenidProfile, :count).by(1)
  end
    
  it "should require an email address to create an account" do
    stub!(:authenticate_with_open_id).and_yield(@result, @identity_url, @registration.except("email"))
    @creating.should change(OpenidProfile, :count).by(0)
    flash[:warning].should == "Your openid did not contain all of the required fields; please complete your registration."
  end
  
  it "should redirect when the openid server is invalid or could not be found." do
    @result = mock('Result', :successful? => false, :message => nil)
    stub!(:authenticate_with_open_id).and_yield(@result, @identity_url, @registration.except("email"))
    @creating.should change(OpenidProfile, :count).by(0)
    flash[:error].should == "Sorry could not log in with identity URL: #{@identity_url}"
  end
end
