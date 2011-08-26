require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::NewsletterController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :newsletters, :members, :stories, :sources, :authorships

  before(:each) do
    add_roles
    @daily  = newsletters(:daily_auto)
    @weekly = newsletters(:weekly_ready)
    @member = members(:heavysixer)
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

  it "should require admin access to view GET /admin/newsletters" do
    should_be_admin_only do
      do_get
    end
    response.should be_success
  end

  it "should return the right newsletter for setup" do
    login_as 'admin'
	 do_get :setup, { :freq => Newsletter::DAILY }
	 response.should be_success
	 assigns[:newsletter].should == @daily

	 @daily.state = Newsletter::IN_TRANSIT
	 @daily.save!
	 do_get :setup, { :freq => Newsletter::DAILY }
	 assigns[:newsletter].should == @daily
	 response.should redirect_to(admin_newsletter_url)
  end

  it "should generate the newsletter for preview" do
    login_as 'admin'
	 do_get :preview, { :freq => Newsletter::DAILY }
	 response.should be_success
	 assigns[:newsletter].should == @daily

	 tmail = assigns[:tmail]
	 tmail.should_not be_nil
  end

  it "should update newsletter properly" do
    login_as 'admin'
    do_put ({ :newsletter => {:id => 1, :subject => "Hi everyone!" }})
    response.should redirect_to(nl_preview_url(:freq => Newsletter::DAILY))
    Newsletter.find(1).subject.should == "Hi everyone!"
  end

  it 'should assign headers and footers from the template when reset' do
    login_as 'admin'
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, @member)
    s = nl.subject
    th = nl.text_header
    tf = nl.text_footer
    hh = nl.html_header
    hf = nl.html_footer
    put :reset_template, :freq => Newsletter::DAILY
    nl.reload
    nl.subject.should_not == s
    nl.text_header.should_not == th
    nl.text_footer.should_not == tf
    nl.html_header.should_not == hh
    nl.html_footer.should_not == hf
  end

  describe "sending test emails" do
    before(:each) do
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      login_as 'admin'
    end
  
    after(:each) do
      ActionMailer::Base.deliveries.clear
    end

    it "should raise error if no recipients provided" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => false, :member_refs => ""}
      ActionMailer::Base.deliveries.size.should be(0)
      response.flash[:error].should_not be_nil
    end

    it "should send mail to myself" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => true, :member_refs => ""}
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should send emails when member email is provided" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => false, :member_refs => "legacy_member@dummydomain.com"}
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should send emails when member name is provided" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => false, :member_refs => "Legacy Member"}
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should send emails to multiple recipients" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => false, :member_refs => "Legacy Member\nsastry@cs.wisc.edu"}
      ActionMailer::Base.deliveries.size.should be(2)
    end

    it "should not send duplicate mails" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => true, :member_refs => "legacy_member@dummydomain.com\nLegacy Member"}
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should not send emails if newsletter delivery is disabled" do
      do_post :send_test_mail, {:freq => Newsletter::DAILY, :to_myself => false, :member_refs => "Mark Daggett"}
      ActionMailer::Base.deliveries.size.should be(0)
    end
  end
end
