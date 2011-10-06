require File.dirname(__FILE__) + '/../spec_helper'

describe MembersController do
  include AuthenticatedTestHelper
  include OpenIdAuthentication
  include RolesystemTestHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  fixtures :all

  describe 'under a rest request' do
    
    it 'allows signup' do
      lambda do
        create_member
        response.should be_redirect
      end.should change(Member, :count).by(1)
    end
  
    it 'requires login on signup' do
      lambda do
        create_member(:email => nil)
        assigns[:member].errors.on(:email).should_not be_nil
        response.should be_success
      end.should_not change(Member, :count)
    end
    
    it 'signs up user with activation code' do
      create_member
      assigns(:member).reload
      assigns(:member).activation_code.should_not be_nil
    end
    
    it 'activates user' do
      Member.authenticate('heavysixers_friend', 'test').should be_nil
      get :activate, :id => members(:heavysixers_friend).activation_code
      response.should redirect_to('/members/my_account#profile')
      response.flash[:notice].should_not be_nil
      Member.authenticate('heavysixer@bar.com', 'test').should == members(:heavysixer)
    end
    
    it 'does not activate user without key' do
      get :activate
      response.flash[:notice].should be_nil
    end
    
    it 'does not activate twice' do
      members(:heavysixer).update_attribute(:status, 'guest')
      Member.authenticate('heavysixers_friend', 'test').should be_nil
      get :activate, :id => members(:heavysixer).activation_code
      response.should redirect_to('/members/my_account#profile')
      response.flash[:notice].should_not be_nil

      get :activate, :id => members(:heavysixer).activation_code
      response.should redirect_to(new_sessions_path)
      response.flash[:error].should_not be_nil
    end
    
    it 'does not activate user with blank key' do
      get :activate, :id => ''
      response.flash[:notice].should be_nil
    end
    
    it 'should determine if login is available' do
      
      # Already Taken
      get :login_available, :format => 'js', :q => 'Mark Daggett'
      response.should be_success
      response.body.should == "1"

      # Already Taken even in some other case
      # This test effectively tests of database encoding --> Failure indicates db is using a case-sensitive encoding
      get :login_available, :format => 'js', :q => 'mArK dAGGeTT'
      response.should be_success
      response.body.should == "1"

      # Not Taken
      get :login_available, :format => 'js', :q => 'Elliott Daggett'
      response.should be_success
      response.body.should == "0"      
    end
  
    it "should display the invite form" do
      @member = members(:heavysixer)
          
      # No session so they get redirected
      get :invite
      response.should redirect_to(new_sessions_path)
  
      @member = spec_login_as(members(:heavysixer))
      get :invite
      response.should be_success
    end
    
    it "should allow users to invite their friends" do
      @member = spec_login_as(members(:heavysixer))
      lambda do
        post :inviting
      end.should_not change(Member, :count)
  
      response.flash[:error].should =~ /A valid email is required/
      response.should redirect_to(invite_members_path)
      
      lambda do
        post :inviting, :member => { :email => 'foo' }
      end.should_not change(Member, :count)
      
      response.flash[:error].should =~ /A valid email is required/
      response.should redirect_to(invite_members_path)
      
      lambda do
        post :inviting, :member => { :email => 'foo@bar.com' }
      end.should change(Member, :count).by(1)
      
      response.flash[:notice].should_not be_empty
      response.should redirect_to(invite_members_path)
    end
    
    it "should require invited users to complete their account" do
      @member = members(:heavysixers_friend)
      get :accept_invitation, :id => @member.activation_code
      response.should be_success
    end
    
    it "should not activate an invited user until their account is valid" do
      @member = members(:heavysixers_friend)
      put :accepting_invitation, :id => @member.activation_code, :member => {:name => ""}  # Invalid member
      response.should be_success
      assigns['member'].active?.should be_false
      
      @member = members(:heavysixers_friend)
      put :accepting_invitation, :id => 'bad_code', :member => { :login => 'foobarbaz', :password => '1qaz2wsx', :password_confirmation => '1qaz2wsx' }
      assigns['member'].active?.should be_false
      response.should redirect_to(new_sessions_path)
      
      @member = members(:heavysixers_friend)
      put :accepting_invitation, :id => @member.activation_code, :member => { :login => 'foobarbaz', :password => '1qaz2wsx', :password_confirmation => '1qaz2wsx' }
      assigns['member'].active?.should be_true
      response.flash[:notice].should =~ /<h2>Sign up complete!<\/h2>Please fill in your profile, to increase your member level./
      response.should redirect_to('/members/my_account#profile')
    end
    
    it "should display an error if the member was already invited by someone else" do
      @member = spec_login_as(members(:heavysixer))
      lambda do
        post :inviting, :member => { :email => @member.email }
      end.should_not change(Member, :count)
      response.flash[:error].should_not be_nil
      response.should redirect_to(invite_members_path)
    end
    
    it "should display an error if the member name is already taken" do
      @member = spec_login_as(members(:heavysixer))
      
    end
    
    it 'requires password on signup' do
      lambda do
        create_member(:password => nil)
        assigns[:member].errors.on(:password).should_not be_nil
        response.should be_success
      end.should_not change(Member, :count)
    end
    
    it 'requires password confirmation on signup' do
      lambda do
        create_member(:password_confirmation => nil)
        assigns[:member].errors.on(:password_confirmation).should_not be_nil
        response.should be_success
      end.should_not change(Member, :count)
    end
  
    it 'requires email on signup' do
      lambda do
        create_member(:email => nil)
        assigns[:member].errors.on(:email).should_not be_nil
        response.should be_success
      end.should_not change(Member, :count)
    end
    
    it 'should allow members to specify their subscriptions' do
      lambda do
        create_member(:newsletter=> {Newsletter::DAILY => true}, :bulk_email => true)
        assigns[:member].has_newsletter_subscription?(Newsletter::DAILY).should be_true
        assigns[:member].has_newsletter_subscription?(Newsletter::WEEKLY).should be_false
        assigns[:member].bulk_email.should be_true
      end.should change(Member, :count)
    end
  end
  
  describe 'when having activity tracked' do
    fixtures :all
    it "should update the last_active_at on every pageload" do
      @member = members(:heavysixer)
      spec_login_as(members(:heavysixer))
      last = @member.last_active_at
      post :last_active_at, :time => Time.now.to_s
      assigns[:current_member].last_active_at.should_not be_nil
      assigns[:current_member].last_active_at.should_not == last
    end
    
    it "should not update the last_active if they are not logged in" do
      post :last_active_at, :time => Time.now.to_s
      response.status.should == "302 Found"
    end
  end
  
  describe 'under an unwanted invitation' do
    fixtures :all
    before(:each) do
      @non_friend = members(:heavysixers_friend)
      @member = members(:heavysixer)
      @member.update_attribute(:status, 'guest')
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
    end
    it "should display a warning to the user about a pending activation" do
      lambda do
        create_member(:name => @member.name, :email => @member.email)
        response.flash[:notice].should =~ /You already signed up, you just need to activate your account. We resent your activation email./
        ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "Welcome to #{APP_NAME} - Activate Your Account"
        ActionMailer::Base.deliveries.first.body.should =~ /#{@member.activation_code}/
        response.should redirect_to(new_member_path)
      end.should_not change(Member, :count)      
    end
    
    it "should display a warning to the user about the pending invitation" do
      lambda do
        create_member(:name => @non_friend.name, :email => @non_friend.email)
        response.flash[:notice].should =~ /This address was sent an invite, we've resent it to you./
        ActionMailer::Base.deliveries.first.body.should =~ /#{@non_friend.referring_member.name} has invited you to join #{APP_NAME}./
        ActionMailer::Base.deliveries.first.body.should =~ /#{@non_friend.activation_code}/
        response.should redirect_to(new_member_path)
      end.should_not change(Member, :count)
    end
    
    it "should not send any emails if the account is active, in this context the email truly is taken." do
      lambda do
        create_member(:name => members(:legacy_member).name, :email => members(:legacy_member).email)
        ActionMailer::Base.deliveries.should be_empty
        response.should be_success
      end.should_not change(Member, :count)
    end
    
  end
  
  describe 'using partner routes' do
    fixtures :all
    before(:each) do
     @partner = partners(:pledgie)
     @invitation = @partner.invitations.first
     ActionMailer::Base.delivery_method = :test
     ActionMailer::Base.perform_deliveries = true
     ActionMailer::Base.deliveries = []
    end
    
    it "should map {:action=>'display_invitation', :invitation_id =>'save-the-rainforests', :partner_id=>'pledgie'} to /partners/pledgie/save-the-rainforests" do
      # SSS: See following url for problem with route_for tesing for nested resources:
      #   http://old.nabble.com/Help-with-nested-routes-test-in-Rails-3-td29062427.html
      # route_for(:action => "display_invitation", :controller => "members", :partner_id => @partner.friendly_id, :invitation_id => @invitation.friendly_id).should == {:path => "/partners/#{@partner.friendly_id}/#{@invitation.friendly_id}"}
      assert_recognizes({:action => "display_invitation", :controller => "members", :partner_id => @partner.friendly_id, :invitation_id => @invitation.friendly_id}, "/partners/#{@partner.friendly_id}/#{@invitation.friendly_id}")
    end
    
    it "should generate params {:partner_id => 'pledgie', :invitation_id => 'save-the-rainforests', :action => 'index', :controller => 'members'} from get /partners/pledgie/save-the-rainforests/members/" do
      params_from(:get, "/partners/pledgie/save-the-rainforests/members").should == { :invitation_id => @invitation.friendly_id, :partner_id => @partner.friendly_id, :action => 'index', :controller => 'members' }
    end
    
  #  it "should generate params {:partner_id => 'pledgie', :action => 'new', :controller => 'members'} from get /signup/pledgie/" do
  #    params_from(:get, "/signup/pledgie").should == { :partner_id => @partner.friendly_id, :action => 'new', :controller => 'members' }
  #  end
    
    it "should use a custom layout if available" do
      get :index, :partner_id => @partner.friendly_id
      response.should be_success
      response.layout.should == "layouts/pledgie"
      
      # Use the default layout
      get :index, :partner_id => Partner.find(partners(:moveon).id).friendly_id
      response.should be_success
      response.layout.should == "layouts/application"
      
      get :index, :partner_id => 'some bad id'
      response.should be_success
      response.layout.should == "layouts/application"
    end
    
    it "should automatically add the new member to the partner's members list and change their validation level" do
      lambda do
        lambda do
          post :create, :partner_id => @partner.friendly_id, :invitation_id => @invitation.friendly_id, :member => { :login => 'quire', :email => 'quire@example.com', :name => "A Quire", :password => 'quire', :password_confirmation => 'quire' }
          assigns['partner'].reload
          assigns['partner'].members.first.login.should == 'quire'
          assigns['current_member'].validation_level.should == @invitation.validation_level
          ActionMailer::Base.deliveries.first.body.should =~ /#{@invitation.invite_message}/
          response.flash[:notice].should_not be_nil
          response.should redirect_to('/start')
        end.should change(Member, :count)
      end.should change(@partner.members, :size).by(1)
    end
    
    it "should redirect the user when a partner's invitation uses links and not templates" do
      
    end
    
  end
  
  fixtures :all

  describe "member profile" do
    it "should redirect from guest & duplicate members" do
      lm = members(:legacy_member)
      get :show, :id => lm.id
      response.should be_success
      
      [Member::GUEST, Member::DUPLICATE].each do |s|
        lm.status = s # note! can't use mass assignment!
        lm.save.should be(true)
        lm.reload.is_public?.should be_false
        
        get :show, :id => lm.id
        response.response_code.should > 400 # either 403 or 404, you get the point
      end
    end

    it "should redirect from members with non-visible profile status" do
      lm = members(:legacy_member)
      get :show, :id => lm.id
      response.should be_success

      (Member::ProfileStatus::ALL-Member::ProfileStatus::VISIBLE).each do |s|
        lm.profile_status = s
        lm.save.should be(true)
        lm.reload.is_visible?.should be_false
        
        get :show, :id => lm.id
        response.response_code.should > 400 # either 403 or 404, you get the point
      end
    end

    it "should redirect from members with hidden member status" do
      lm = members(:legacy_member)
      get :show, :id => lm.id
      response.should be_success

      Member::INACTIVE_STATUS_CHOICES.each do |s|
        lm.status = s # note! can't use mass assignment!
        lm.save.should be(true)
        lm.reload.is_public?.should be_false
        
        get :show, :id => lm.id
        response.should redirect_to(home_url)
        response.flash[:error].should =~ /No Member Found/
      end
    end
    
    it "should not display reviews from a deleted member" do
      get :reviews, :id => members(:deleted_member).id
      response.should redirect_to(home_url)
      response.flash[:error].should_not be_empty
    end
  end

  it "should render edits for my_account" do
    @member = spec_login_as(members(:heavysixer))
    post :my_account
    response.should render_template('edit')
    response.should be_success
  end

  it "should not allow non-admins access to edit_account" do
    @member = spec_login_as(members(:heavysixer))
    add_roles
    should_be_admin_only do
      post :edit_account, :id => members(:legacy_member).id
    end
    response.should be_success
  end

  it "should allow admins access to edit_account" do
    add_roles
    login_as 'admin'
    post :edit_account, :id => members(:legacy_member).id
    response.should be_success
    response.should render_template('edit')
    assigns[:member].should == members(:legacy_member)
  end

  it "should render mynetwork" do
    @member = spec_login_as(members(:heavysixer))
    post :mynetwork, :id => @member.id
    response.should render_template('mynetwork')
    response.should be_success
  end

  it "should enforce student privacy constraints if educational status is set to student" do
    @member = spec_login_as(members(:heavysixer))
    @member.update_attributes({:show_email => true, :show_profile => Member::Visibility::PUBLIC})
    post :update, :id =>@member.id, :member => {:id => @member.id}, :member_attributes => { :educational_status => { :value => Member::EducationalStatus::HIGH_SCHOOL, :visible => 1} }
    @member.reload
    @member.educational_status.should == Member::EducationalStatus::HIGH_SCHOOL
    @member.show_email.should be_false
    @member.show_profile.should == Member::Visibility::PRIVATE
  end

  describe "subscription management" do
    it "should respond to newsletter management pages" do
      @member = spec_login_as(members(:heavysixer))
      (Newsletter::VALID_NEWSLETTER_TYPES+[Newsletter::BULK]).each { |freq|
        get :manage_subscription, :freq => freq, :id => @member.id
        response.response_code.should == 200
        response.should render_template("members/manage_#{freq}")
      }
    end

    it "should unsubscribe from daily/weekly newsletter" do
      @member = members(:heavysixer)
      f = Newsletter::DAILY
      @member.add_newsletter_subscription(f)
      @member.has_newsletter_subscription?(f).should be_true
      post :unsubscribe_from_newsletter, :freq => f, :key => @member.newsletter_unsubscribe_key(f)
      @member.has_newsletter_subscription?(f).should be_false
    end

    it "should update newsletter subscriptions"
  end
  
  def create_member(options = {})
    post :create, :member => { :login => 'quire', :email => 'quire@example.com', :name => "A Quire",
      :password => 'quire', :password_confirmation => 'quire' }.merge(options)
  end
end
