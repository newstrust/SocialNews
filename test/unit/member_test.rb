require File.dirname(__FILE__) + '/../test_helper'

class MemberTest < ActiveSupport::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  include AuthenticatedTestHelper
  fixtures :members
  
  def test_should_authenticate_member
    assert_equal members(:legacy_member), Member.authenticate('legacy_member@newstrust.net', 'test')
  end
  
  def test_should_create_member
    assert_difference Member, :count do
      member = create_member
      assert !member.new_record?, "#{member.errors.full_messages.to_sentence}"
    end
    assert Member.authenticate('johnny_come_lately@newstrust.net', 'newkid')
  end
  
  def test_should_require_password
    assert_no_difference Member, :count do
      u = create_member(:password => nil)
      assert u.errors.on(:password)
    end
  end
  
  def test_should_require_password_confirmation
    assert_no_difference Member, :count do
      u = create_member(:password_confirmation => nil)
      assert u.errors.on(:password_confirmation)
    end
  end
  
  def test_should_require_email
    assert_no_difference Member, :count do
      u = create_member(:email => nil)
      assert u.errors.on(:email)
    end
  end
  
  def test_should_reset_password
    members(:legacy_member).update_attributes(:password => 'new password', :password_confirmation => 'new password')
    assert_equal members(:legacy_member), Member.authenticate('legacy_member@newstrust.net', 'new password')
  end
  
  def test_should_not_rehash_password
    members(:legacy_member).update_attributes(:email => 'legacy_member_pseudonymized@newstrust.net')
    assert_equal members(:legacy_member), Member.authenticate('legacy_member_pseudonymized@newstrust.net', 'test')
  end
  
  # NOTE: wiped out restful_authentication's 'remember me' tests,
  # as that code isn't currently being exercized anyway.
  
  
  protected
  
    def create_member(options = {})
      record = Member.new({
          :login => 'johnny_come_lately@newstrust.net',
          :email => 'johnny_come_lately@newstrust.net',
          :name => 'Johnny Come Lately',
          :password => 'newkid',
          :password_confirmation => 'newkid' }.merge(options))
      record.save
      record
    end
    
end
