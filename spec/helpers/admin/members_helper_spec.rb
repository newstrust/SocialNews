require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::MembersHelper do
  include Admin::MembersHelper
  
  #Delete this example and add some real ones or delete this file
  it "should include the Admin::MembersHelper" do
    included_modules = (class << helper; self; end).send :included_modules  
    included_modules.should include(Admin::MembersHelper)
  end  
end
