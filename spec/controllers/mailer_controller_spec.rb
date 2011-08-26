require File.dirname(__FILE__) + '/../spec_helper'

describe MailerController do
  include AuthenticatedTestHelper
  describe 'handling POST mailer/send_to_friend' do
    fixtures :all
    
    before(:each) do
      @message = { :record_id => 11, :to => 'foo@bar.com', :from => 'bar@baz.com', :from_name => 'Jo Jo', :body => '', :template => 'member_profile', :page => 'http://localhost:3000/members/6813' }
      @params = { :format => 'js', :message => @message }
    end
    
    def do_post(opts = {})
      post :send_to_friend, opts
    end
    
    it 'should require login' do
      do_post @params
      response.status.should == "401 Unauthorized"
    end
        
    it "should not send to invalid or empty addresses in the 'to:' field" do
      spec_login_as(members(:heavysixer))
      @message[:to] = nil
      do_post @params
      response.flash[:error].should == "Please specify at least one recipient."
      response.status.should == "406 Not Acceptable"
      
      @message[:to] = 'bad address'
      do_post @params
      response.status.should == "406 Not Acceptable"
      json_response = ActiveSupport::JSON.decode(response.body)
      json_response["flash"]["error"].should == "The recipient address is malformed."
    end
    
    it "should not send when the requested record is invalid" do
      spec_login_as(members(:heavysixer))
      Member.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      recipients = []
      2.times {|x| recipients << "foo#{x}@bar.com" }
      @message[:to] = recipients.join(',')
      do_post @params
      json_response = ActiveSupport::JSON.decode(response.body)
      response.status.should == "406 Not Acceptable"
      json_response["flash"]["error"].should == "ActiveRecord::RecordNotFound"
    end
    
    it "should require a valid template" do
      spec_login_as(members(:heavysixer))
      @message[:template] = nil
      do_post @params
      response.status.should == "406 Not Acceptable"
      json_response = ActiveSupport::JSON.decode(response.body)
      json_response["flash"]["error"].should == response.flash[:error]
      
      @message[:template] = "home"
      do_post @params
      response.status.should == "200 OK"
    end
    
    it "should not send more than 25 emails" do
      spec_login_as(members(:heavysixer))
      recipients = []
      50.times {|x| recipients << "foo#{x}@bar.com" }
      @message[:to] = recipients.join(',')
    
      do_post @params
      response.flash[:warning].should == "Maximum 25 emails already sent."
      response.status.should == "200 OK"
      json_response = ActiveSupport::JSON.decode(response.body)
      json_response["flash"]["warning"].should == "Maximum 25 emails already sent."
      json_response["sent"].should_not be_empty
      json_response["unsent"].should_not be_empty
      json_response["undeliverable"].should be_empty
    end
    
    it "should send a confirmation email to the user, whenever a message is successfully sent."
  end
end
