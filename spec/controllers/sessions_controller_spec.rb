require File.dirname(__FILE__) + '/../spec_helper'

describe SessionsController do
  include AuthenticatedTestHelper
  include OpenIdAuthentication

  fixtures :all

  it 'logins and redirects' do
    post :create, :email => 'legacy_member@dummydomain.com', :password => 'test'
    session[:member_id].should_not be_nil
    response.should be_redirect
  end

  it 'does not login terminated members' do
    members(:legacy_member).update_attribute(:status, Member::TERMINATED)
    post(:create, :email => 'legacy_member@dummydomain.com', :password => 'test')
    session[:member_id].should be_nil
  end

  it 'redirects to my_account page for logins after password reset' do
    m = Member.find_by_email('legacy_member@dummydomain.com')
    m.update_attribute(:password_reset, true)
    post :create, :email => 'legacy_member@dummydomain.com', :password => 'test'
    session[:member_id].should_not be_nil
    response.should redirect_to("/members/my_account#account")
    m.reload.password_reset.should == false
  end
  
  it 'fails login and does not redirect' do
    post :create, :email => 'legacy_member@dummydomain.com', :password => 'bad password'
    session[:member_id].should be_nil
    response.should be_success
  end

  it 'logs out' do
    login_as :legacy_member
    get :destroy
    session[:member_id].should be_nil
    response.should be_redirect
  end
  
  it 'should not reset the password without the right parameters' do
    post :reset_password
    response.flash[:error].should == "You must specify an email address"
    response.should redirect_to(forgot_password_sessions_path)
  end
  
  it 'should require a valid email address to reset the password' do
    post :reset_password, :email => 'foo@bar.com'
    response.flash[:error].should_not be_nil
    response.should redirect_to(forgot_password_sessions_path)
  end
  
  it "should resend the activation email for members who lost the original email" do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    member = members(:heavysixers_friend)
    post :resending_activation, :email => member.email
    response.should redirect_to(resend_activation_sessions_path)
    assigns['member'].should_not be_nil
    response.flash[:notice].should_not be_nil
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "Welcome to #{SocialNewsConfig["app"]["name"]} - Activate Your Account"
    ActionMailer::Base.deliveries.first.body.should =~ /#{assigns['member'].activation_code}/
  end

  it "should recreate the activation code for inactive members without activation code" do
    m = members(:heavysixer)
    m.activation_code.should_not be_nil
    m.activate

      # Set to guest status and save!
    m.activation_code.should be_nil
    m.status = "guest"
    m.save!

      # Try to resend activation
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    post :resending_activation, :email => m.email

      # The activation code shoudl not be nil!
    response.should redirect_to(resend_activation_sessions_path)
    assigns['member'].should_not be_nil
    response.flash[:notice].should_not be_nil
    ActionMailer::Base.deliveries.first.body.should =~ %r|members/activate/\w+\s+|
  end

  it "should not resend the activation email to members who are already active" do
    member = members(:heavysixer)
    member.activate
    post :resending_activation, :email => member.email
    response.should redirect_to(resend_activation_sessions_path)
    response.flash[:notice].should =~ /Your account is already active/i
  end
  
  it "should not resend the activation email for unknown emails" do
    post :resending_activation, :email => 'foo@bar.com'
    assigns['member'].should be_nil
    response.flash[:error].should_not be_nil
    response.should redirect_to(resend_activation_sessions_path)
  end

  it 'should redirect and display an error if the password was not changed' do
    @member = members(:legacy_member)
    @member.stub!(:update_attributes).and_return(false)
    Member.stub!(:find_by_email).and_return(@member)
    
    post :reset_password, :email => @member.email
    response.flash[:error].should == "There was an error resetting your password"
    response.should redirect_to(forgot_password_sessions_path)
  end
  
  it 'should reset a lost password' do
    post :reset_password, :email => 'legacy_member@dummydomain.com'
    response.flash[:notice].should == "Your temporary password has been mailed to legacy_member@dummydomain.com"
    response.should redirect_to(new_sessions_path)
  end

  it 'remembers me' do
    post :create, :email => 'legacy_member@dummydomain.com', :password => 'test', :remember_me => "1"
    response.cookies["auth_token"].should_not be_nil
  end
  
  it 'does not remember me' do
    post :create, :email => 'legacy_member@dummydomain.com', :password => 'test', :remember_me => "0"
    response.cookies["auth_token"].should be_nil
  end

  it 'deletes token on logout' do
    login_as :legacy_member
    get :destroy
    response.cookies["auth_token"].should be_nil
  end

  it 'logs in with cookie' do
    members(:legacy_member).remember_me
    request.cookies["auth_token"] = cookie_for(:legacy_member)
    get :new
    controller.send(:logged_in?).should be_true
  end
  
  it 'fails expired cookie login' do
    members(:legacy_member).remember_me
    members(:legacy_member).update_attribute :remember_token_expires_at, 5.minutes.ago
    request.cookies["auth_token"] = cookie_for(:legacy_member)
    get :new
    controller.send(:logged_in?).should_not be_true
  end
  
  it 'fails cookie login' do
    members(:legacy_member).remember_me
    request.cookies["auth_token"] = auth_token('invalid_auth_token')
    get :new
    controller.send(:logged_in?).should_not be_true
  end
  
  it "should hide login form from bots" do
    pending("ugh doesn't work because of mocked ActionController::TestSession")
    GOOGLEBOT_USER_AGENT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    request.stub!(:user_agent).and_return(GOOGLEBOT_USER_AGENT)
    get :new #, {}, {:user_agent => "bot"}
    response.response_code.should == 403
  end
  
  def auth_token(token)
    CGI::Cookie.new('name' => 'auth_token', 'value' => token)
  end
    
  def cookie_for(member)
    auth_token members(member).remember_token
  end
end
