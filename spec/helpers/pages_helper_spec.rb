require File.dirname(__FILE__) + '/../spec_helper'

describe PagesHelper do
  include PagesHelper
  #Delete this example and add some real ones or delete this file
  it "should include the PagesHelper" do
    included_modules = (class << helper; self; end).send :included_modules  
    included_modules.should include(PagesHelper)
  end
  
end
