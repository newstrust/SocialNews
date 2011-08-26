require File.dirname(__FILE__) + '/../spec_helper'

describe FeedsController do
  include RolesystemTestHelper
  fixtures :all

  it "should not let guests view facebook newsfeed pages"
  it "should let admin view facebook newsfeed pages"
  it "should let members view their own facebook newsfeed pages"
end
