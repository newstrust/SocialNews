require File.dirname(__FILE__) + '/../test_helper'
require 'members_controller'

# Re-raise errors caught by the controller.
class MembersController; def rescue_action(e) raise e end; end

class MembersControllerTest < ActionController::TestCase
  def self.helper_method(*args); end
  include OpenidProfilesHelper
  
  fixtures :members

  def setup
    @controller = MembersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_allow_signup
    assert_difference Member, :count do
      create_member
      assert_response :redirect
    end
  end
  
  def test_should_require_password_on_signup
    assert_no_difference Member, :count do
      create_member(:password => nil)
      assert assigns(:member).errors.on(:password)
      assert_response :success
    end
  end
  
  def test_should_require_password_confirmation_on_signup
    assert_no_difference Member, :count do
      create_member(:password_confirmation => nil)
      assert assigns(:member).errors.on(:password_confirmation)
      assert_response :success
    end
  end
  
  def test_should_require_email_on_signup
    assert_no_difference Member, :count do
      create_member(:email => nil)
      assert assigns(:member).errors.on(:email)
      assert_response :success
    end
  end
  

  protected
    def create_member(options = {})
      post(:create, {:member => {
        :login => 'johnny_come_lately@newstrust.net',
        :email => 'johnny_come_lately@newstrust.net',
        :name => 'Johnny Come Lately',
        :password => 'newkid',
        :password_confirmation => 'newkid' }.merge(options)},
        {:user_agent => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_4; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.2 Safari/525.20.1"})
    end
end
