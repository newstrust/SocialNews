require File.dirname(__FILE__) + '/../spec_helper'

describe FollowedItemsController do
  include AuthenticatedTestHelper

  fixtures :all

  def follow(followable_id, followable_type)
    post :follow, :format => "js", :followable_id => followable_id, :followable_type => followable_type
  end

  it "should require login" do
    resp = follow(1, "member")
    resp.should be_success
    resp.body.should =~ /"success":\s*false/
    resp.body.should =~ /"error":\s*"No logged in member found.*"/
  end
  
  describe 'following items' do
    before(:each) do
      @member = members(:heavysixer)
      spec_login_as(@member)
    end

    it "should not follow myself" do
      resp = follow(@member.id, "member")
      resp.body.should =~ /"success":\s*false/
      resp.body.should =~ /"error":\s*"Cannot follow yourself!"/
    end

    it "should follow a member" do
      lm = members(:legacy_member)
      resp = follow(lm.id, "member")
      resp.body.should =~ /"success":\s*true/
      resp.body.should =~ /"created":\s*true/
      @member.reload.followed_members.map(&:id).should == [lm.id]
    end

    it "should stop following a member" do
      lm = members(:legacy_member)
      resp = follow(lm.id, "member")
      resp.body.should =~ /"success":\s*true/
      resp.body.should =~ /"created":\s*true/
      @member.reload.followed_members.map(&:id).should == [lm.id]
      lm = members(:legacy_member)
      resp = follow(lm.id, "member")
      resp.body.should =~ /"success":\s*true/
      resp.body.should =~ /"created":\s*false/
      @member.reload.followed_members.map(&:id).should be_empty
    end

    it "should not follow unknown types" do
      resp = follow(@member.id, "alien")
      resp.body.should =~ /"success":\s*false/
      resp.body.should =~ /"error":\s*"Cannot follow.*Only members.*can be followed."/
    end
  end
end
