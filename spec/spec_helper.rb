# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path(File.join(File.dirname(__FILE__),'..','config','environment'))
require 'spec/autorun'
require 'spec/rails'

# Uncomment the next line to use webrat's matchers
#require 'webrat/integrations/rspec-rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

include UploadedFileTestHelper
Spec::Runner.configure do |config|
  # If you're not using ActiveRecord you should remove these
  # lines, delete config/database.yml and disable :active_record
  # in your config/boot.rb
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
    
  module Spec
    module Mocks
      module Methods
        def stub_association!(association_name, methods_to_be_stubbed = {})
          mock_association = Spec::Mocks::Mock.new(association_name.to_s)
          methods_to_be_stubbed.each do |method, return_value|
            mock_association.stub!(method).and_return(return_value)
          end
          self.stub!(association_name).and_return(mock_association)
        end
      end
    end
  end
  
  def ar_methods
    { :save => true, :destroy => true, :update_attributes => true }
  end
  
  def mock_openid_profile(opts = {})
    @openid_profile = mock_model(OpenidProfile, ar_methods.merge(opts))
  end
  
  def mock_comment(opts = {})
    @comment = mock_model(Comment, ar_methods.merge({ :deliver_notifications => true, :commentable_type => 'Tag', :parent => nil }.merge(opts)))
  end
  
  def spec_login_as(member)
    Member.stub!(:find_by_id).and_return(member)
    request.session[:member_id] = member.id
    member
  end

  def mock_member(opts = {})
    @member = mock_model(Member, { :can_comment? => true, :terminated? => false, :login => 'foobarbaz', :name => 'foo bar', :email => 'foo@bar.com', :muzzled => false, :id => 101, :image => nil }.merge(opts))
    @member.stub_association!(:openid_profiles, :create => true, :build => mock_openid_profile)
    @member.stub_association!(:comments, :create => true, :build => mock_comment, :find => mock_comment)
    @member
  end
  
  def mock_invitation(opts = {})    
    @invitation = mock_model(Invitation, { 
      :name => 'mock invite', 
      :additional_signup_fields =>'', 
      :welcome_page_template => '', 
      :code =>'sekret', 
      :landing_page_template => '', 
      :email_from => 'foo@bar.com', 
      :partner_id => 1, 
      :validation_level => 5, 
      :email_subject => 'please sign up', 
      :invite_message => 'please complete your account' 
    })
  end

  def mock_smtp
    @sender = Net::SMTP.new(nil)
    @sender.stub_association!(:dummy_smtp, "start" => nil, "started?" => true, "send_message" => nil, "finish" => nil)
  end
  
  def mock_sreg_response
    { "fullname" => "Mark Daggett 2", "email" => 'foo@bar.com', "ns_alias" => "sreg", "ns_uri" => "http://openid.net/extensions/sreg/1.1" }
  end    

  def mock_member_path(m)
    "/members/#{m.id}"
  end

  describe "A Registered Member", :shared => true do
    before(:each) do
      @member = mock_member
      Member.stub!(:find).and_return(@member)
    end
  end
  
  describe "A valid session", :shared => true do
    before(:each) do
      @member = mock_member
      Member.stub!(:find_by_id).and_return(@member)
      request.session[:member_id] = @member.id
    end
  end
  
  describe "A valid response from an openid provider", :shared => true do
    before(:each) do
      # Both of these methods are part of the open_id_authentication plugin
      self.stub!(:using_open_id?).and_return(true)
      
      params.merge({ "openid.sreg.fullname" => "Mark Daggett", 
                                         "openid.sig" => "LjERIp1ikaEzpnLNYPNqN5pB8Ko=", 
                                         "openid.return_to" => "http://localhost:3000/sessions?open_id_complete=1&openid1_claimed_id=https%3A%2F%2Ffoo.myopenid.com%2F&rp_nonce=2008-05-10T16%3A37%3A19ZOhaO2J", 
                                         "openid.mode" => "id_res", 
                                         "openid.op_endpoint" => "https://www.myopenid.com/server", 
                                         "rp_nonce" => "2008-05-10T16:37:19ZOhaO2J", 
                                         "openid.response_nonce" => "2008-05-10T16:38:20ZTPbBLa",
                                         "openid.sreg.email" => "foo@bar.com", 
                                         "controller" => "sessions", 
                                         "openid.identity" => "https://foo.myopenid.com/", 
                                         "openid1_claimed_id" => "https://foo.myopenid.com/", 
                                         "open_id_complete" => "1", 
                                         "openid.signed" => "assoc_handle,identity,mode,op_endpoint,response_nonce,return_to,signed,sreg.email,sreg.fullname", 
                                         "openid.assoc_handle" => "{HMAC-SHA1}{4825cdbf}{rcQpaA==}"
                                        })
    end

  end

end

class MockMember
  def initialize(opts)
    @roles = opts[:roles] if opts[:roles]
  end

  def has_specific_role?(role)
    roles.map(&:slug).include?(role.to_s)
  end

  def has_role?(role)
    has_role_or_above?(role)
  end

  def has_role_or_above?(role)
    role_index = RolesystemTestHelper.all_mock_roles.index(role.to_s)
    return false if role_index.nil?

    required_roles = RolesystemTestHelper.all_mock_roles[0, role_index+1]
    return !(roles.map(&:slug) & required_roles).empty?
  end

  def has_host_privilege?(hostable, override_role, local_site=nil)
    has_role_or_above?(override_role)
  end

  # This is the id of member 11 (legacy_member)!
  # IMPORTANT: Some spec tests seem to rely on there being a fixture for the member whose id this is!
  def id; 11; end
  def display_name; "Mock Member"; end
  def image; nil; end
  def can_comment?; true; end
  def status; "member"; end
  def fbc_linked?; false; end
  def is_public?; true; end
  def is_visible?; true; end
  def fbc_linked?; false; end
  def terminated?; false; end
  def name; "Legacy Member"; end
  def preferred_review_form_version; ""; end
  def roles; @roles; end
  def rating; 3.5; end
  def email; "legacy_member@socialnews.com"; end
  def newsletter_unsubscribe_key(nl); "mock_key"; end
  def activation_code; "not_required"; end
end
