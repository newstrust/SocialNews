require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::BulkEmailsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  fixtures :all

  before(:each) do
    add_roles
  end
    
  def do_get(action = :index, opts = {})
    get action, opts
  end
    
  def do_post(action, opts = {})
    post action, :bulk_email => opts
  end

  it "should require admin access to view GET /admin/bulk_emails" do
    should_be_admin_only do
      do_get(:index)
    end
    response.should be_success
  end

  describe "sending bulk emails" do
    before(:each) do
      login_as 'admin'
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      @lm = members(:legacy_member)
      @mail_opts = { :from => "subbu@dummydomain.com", :subject => "", :body => "" }
    end
  
    after(:each) do
      ActionMailer::Base.deliveries.clear
    end

    it "should raise error if no recipients provided" do
      do_post :send_mail, @mail_opts.merge({:to => ""})
      ActionMailer::Base.deliveries.size.should be(0)
      response.flash[:error].should_not be_nil
    end

    it "should send emails when member email is provided" do
      do_post :send_mail, @mail_opts.merge({:to => "legacy_member@dummydomain.com"})
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should send emails when member name is provided" do
      do_post :send_mail, @mail_opts.merge({:to => "Legacy Member"})
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it "should send emails to multiple recipients" do
      do_post :send_mail, @mail_opts.merge({:to => "Legacy Member\nsastry@cs.wisc.edu"})
      ActionMailer::Base.deliveries.size.should be(2)
    end

    it "should not send duplicate mails" do
      do_post :send_mail, @mail_opts.merge({:to => "legacy_member@dummydomain.com\nLegacy Member"})
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it 'should not send reinvites to non-guest status members' do
      do_post :send_mail, @mail_opts.merge({:to => "Legacy Member", :is_reinvite => "true"})
      ActionMailer::Base.deliveries.size.should be(0)
    end

    it 'should not send mass email to member with bulk_email option unchecked' do
      do_post :send_mail, @mail_opts.merge({:to => "Mark Daggett"})
      ActionMailer::Base.deliveries.size.should be(0)
    end

    it 'should send mass email to member with bulk_email option unchecked and bulk email override checked' do
      do_post :send_mail, @mail_opts.merge({:to => "Mark Daggett", :ignore_no_bulk_email => "true"})
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it 'should send reinvite to guest with bulk_email option unchecked, even without checking bulk email override' do
      do_post :send_mail, @mail_opts.merge({:to => "Friend of Heavsixer", :is_reinvite => "true"})
      ActionMailer::Base.deliveries.size.should be(1)
    end

    it 'should initialize invitation codes when given one and there is no existing code' do
      @lm.update_attributes({:status => "guest", :invitation_code => ""})
      do_post :send_mail, @mail_opts.merge({:to => "Legacy Member", :is_reinvite => "true", :invitation_code => "xyz"})
      ActionMailer::Base.deliveries.size.should be(1)
      @lm.reload.invitation_code.should == "xyz"
    end

    it 'should update invitation codes when given one and there is an existing code' do
      @lm.update_attributes({:status => "guest", :invitation_code => "123"})
      do_post :send_mail, @mail_opts.merge({:to => "Legacy Member", :is_reinvite => "true", :invitation_code => "xyz"})
      ActionMailer::Base.deliveries.size.should be(1)
      @lm.reload.invitation_code.should == "123,xyz"
    end
  end
end
