require File.dirname(__FILE__) + '/../spec_helper'

describe MynewsController do
  include AuthenticatedTestHelper
  fixtures :all

  before(:each) do
	 @member = members(:heavysixer)
  end

  it 'should send visitors to login page if not logged in' do
	  get :mynews, :member_id => @member.id
	  response.should redirect_to(new_sessions_path)
  end

  it 'should send members to mynews page if logged in' do
	  spec_login_as(@member)
	  get :mynews, :member_id => @member.id
	  response.response_code.should == 200
  end

  it 'should not allow access to mynews pages of terminated members' do
	  spec_login_as(@member)
    @member.update_attributes(:public_mynews => "public")
    @member.update_attribute(:status, 'terminated')
	  get :mynews, :member_id => @member.id
    response.status.should =~ /403/
  end
end
