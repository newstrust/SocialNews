require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::PartnersHelper do
  include Admin::PartnersHelper
  
  #Delete this example and add some real ones or delete this file
  it "should include the Admin::PartnersHelper" do
    included_modules = (class << helper; self; end).send :included_modules  
    included_modules.should include(Admin::PartnersHelper)
  end
  
end
