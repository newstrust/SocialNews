require File.dirname(__FILE__) + '/../test_helper'
require 'sessions_controller'

# Re-raise errors caught by the controller.
class SessionsController; def rescue_action(e) raise e end; end
ActionController::Base.send :include, OpenIdAuthentication
class SessionsControllerTest < ActionController::TestCase
  def self.helper_method(*args); end
  include OpenidProfilesHelper
  include AuthenticatedSystem
  fixtures :members, :openid_profiles, :open_id_authentication_associations

  def setup
    @controller = SessionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_should_login_and_redirect
    post :create, :email => 'legacy_member@newstrust.net', :password => 'test'
    assert session[:member_id]
    assert_response :redirect
  end
  
  def test_should_fail_login_and_not_redirect
    post :create, :email => 'legacy_member@newstrust.net', :password => 'bad password'
    assert_nil session[:member_id]
    assert_response :success
  end
  
  def test_should_logout
    login_as :legacy_member
    get :destroy
    assert_nil session[:member_id]
    assert_response :redirect
  end
  
  # NOTE: wiped out restful_authentication's 'remember me' tests,
  # as that code isn't currently being exercized anyway.
  
  protected
    
    def auth_token(token)
      CGI::Cookie.new('name' => 'auth_token', 'value' => token)
    end
    
    def cookie_for(member)
      auth_token members(member).remember_token
    end
    
end
