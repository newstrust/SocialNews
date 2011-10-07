require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::DashboardController do
  fixtures :all
  
  before(:each) do
    @member = members(:heavysixer)
    @admin_role = groups(:admins)
    @member.groups << @admin_role
    Member.stub!(:find_by_id).and_return(@member)
    request.session[:member_id] = @member.id
  end
  
  def do_get
    get :index
  end
  it "should require login and admin access" do
    do_get
    response.should be_success
    
    @member.memberships.delete_all
    do_get
    response.should redirect_to(home_path)
  end
end
