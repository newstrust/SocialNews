require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::GroupsHelper do
  include Admin::GroupsHelper
  
  #Delete this example and add some real ones or delete this file
  it "should include the Admin::GroupsHelper" do
    included_modules = (class << helper; self; end).send :included_modules  
    included_modules.should include(Admin::GroupsHelper)
  end
  
end
