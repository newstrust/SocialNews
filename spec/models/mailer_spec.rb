require File.dirname(__FILE__) + '/../spec_helper'

describe Mailer do
  fixtures :all

  before(:each) do
    @member = members(:heavysixer)
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  it "should validate email formats" do
    Mailer.valid_email_address?().should be_false
    Mailer.valid_email_address?(nil).should be_false
    Mailer.valid_email_address?('foo').should be_false
    Mailer.valid_email_address?('foo@bar.com').should be_true
  end
  
  it "should be able to find templates to use when sending to friends" do
    record, @template = Mailer.find_template({ :template => 'foo', :record_id => '19' })
    @template.should == "generic.erb"
    
    Story.stub!(:find).and_return(mock_model(Story))
    record, @template = Mailer.find_template({ :template => 'home', :record_id => 10 })
    @template.should == "home.erb"
  end
  
  it "should send to friend" do
    @params = { 
      :to => 'foo@bar.com', 
      :from => 'bar@baz.com', 
      :from_name => 'Bar Bar', 
      :body => 'You have to read this!', 
      :page => 'http://www.google.com'
    }
    @template = "home.erb"
    Mailer.deliver_send_to_friend(@params, @template)
    ActionMailer::Base.deliveries.size.should be(1)
    
    # The message should include the footer text
    ActionMailer::Base.deliveries.first.from.first.should == @params[:from]
    ActionMailer::Base.deliveries.first.to.first.should == @params[:to]
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "#{@params[:from_name]} sent you a link to #{APP_NAME}"
    ActionMailer::Base.deliveries.first.body.should =~ /#{@params[:body]}/
    ActionMailer::Base.deliveries.first.body.should =~ /ABOUT #{SocialNewsConfig["app"]["name"]}/i
  end
  
  it "should deliver an email when someone resets their password" do
    @pass = "some_fake_password"
    Mailer.deliver_reset_password(
      :subject => "Password Reset",
      :recipients => @member.email,
      :body => { :pass => @pass }
    )
    ActionMailer::Base.deliveries.size.should be(1)
    ActionMailer::Base.deliveries.first.from.first.should == SocialNewsConfig["email_addrs"]["support"] 
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "Password Reset"
    ActionMailer::Base.deliveries.first.to.first.should == "heavysixer@bar.com"
    ActionMailer::Base.deliveries.first.body.should =~ /#{@pass}/
  end
  
  it "should deliver an invitation email when someone signs you up for a new account" do
    @member.referred_by = members(:legacy_member).id
    @member.save
    Mailer.deliver_signup_invitation_notification(@member)
    ActionMailer::Base.deliveries.size.should be(1)
    ActionMailer::Base.deliveries.first.from.first.should == SocialNewsConfig["email_addrs"]["signup"]
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "#{members(:legacy_member).name} invited you to join #{APP_NAME}"
    ActionMailer::Base.deliveries.first.to.first.should == "heavysixer@bar.com"
    ActionMailer::Base.deliveries.first.body.should =~ /#{members(:legacy_member).name} has invited you to join #{APP_NAME}./
    ActionMailer::Base.deliveries.first.body.should =~ /#{@member.activation_code}/
  end

  it "should deliver an activation request email when someone creates an account" do
    @member.password = "sekret_password"
    Mailer.deliver_signup_notification(@member)
    ActionMailer::Base.deliveries.size.should be(1)
    ActionMailer::Base.deliveries.first.from.first.should == SocialNewsConfig["email_addrs"]["signup"]
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "Welcome to #{APP_NAME} - Activate Your Account"
    ActionMailer::Base.deliveries.first.to.first.should == "heavysixer@bar.com"
    ActionMailer::Base.deliveries.first.body.should_not =~ /sekret_password/
    ActionMailer::Base.deliveries.first.body.should =~ /#{@member.email}/
    ActionMailer::Base.deliveries.first.body.should =~ /#{@member.activation_code}/
  end
  
  it "should deliver an activation request email when someone creates an account through a partner invitation" do
    @member.password = "sekret_password"
    Mailer.deliver_signup_notification(@member)
    ActionMailer::Base.deliveries.size.should be(1)
    ActionMailer::Base.deliveries.first.from.first.should == SocialNewsConfig["email_addrs"]["signup"]
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "Welcome to #{APP_NAME} - Activate Your Account"
    ActionMailer::Base.deliveries.first.to.first.should == "heavysixer@bar.com"
    ActionMailer::Base.deliveries.first.body.should_not =~ /sekret_password/
    ActionMailer::Base.deliveries.first.body.should =~ /#{@member.email}/
    ActionMailer::Base.deliveries.first.body.should =~ /#{@member.activation_code}/
  end
  
  it "should deliver an activation confirmation email when someone activates their account" do
    @member.password = "sekret_password"
    @member.invitation = mock_invitation
    Mailer.deliver_partner_signup_notification(@member)
    
    ActionMailer::Base.deliveries.size.should be(1)
    ActionMailer::Base.deliveries.first.from.first.should == "foo@bar.com"
    ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "please sign up"
    ActionMailer::Base.deliveries.first.to.first.should == "heavysixer@bar.com"
    ActionMailer::Base.deliveries.first.body.should =~ /please complete your account/
  end

  describe Newsletter do
    fixtures :all

    before(:each) do
      @newsletter = newsletters(:daily_auto)
    end

    def perform_common_checks
      ActionMailer::Base.deliveries.size.should be(1)
      ActionMailer::Base.deliveries.first.from.first.should == SocialNewsConfig["email_addrs"]["news"]
      ActionMailer::Base.deliveries.first.to.first.should == "#{@member.email}"
    end

    it "should send text version of the newsletter when invoked" do
      Mailer.deliver_text_newsletter(@newsletter, @member)
      first_name = @member.name.split("\s").first
      perform_common_checks
      ActionMailer::Base.deliveries.first.content_type.should == "text/plain"
      ActionMailer::Base.deliveries.first.body.should =~ /Hello #{first_name}/
    end
    
    it "should send html version of the newsletter when invoked" do
      Mailer.deliver_html_newsletter(@newsletter, @member)
      first_name = @member.name.split("\s").first
      perform_common_checks
      ActionMailer::Base.deliveries.first.content_type.should == "multipart/alternative"
      ActionMailer::Base.deliveries.first.body.should =~ /Hello #{first_name}.*Hello #{first_name}/m
    end
  end
  
  after(:each) do
    ActionMailer::Base.deliveries.clear
  end
end
