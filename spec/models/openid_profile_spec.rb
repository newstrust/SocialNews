require File.dirname(__FILE__) + '/../spec_helper'

describe OpenidProfile do
  before(:each) do
    @openid_profile = OpenidProfile.new
  end

  it "should be valid" do
    @openid_profile.should be_valid
  end
end
