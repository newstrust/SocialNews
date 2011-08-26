require File.dirname(__FILE__) + '/../spec_helper'

describe Membership do
  fixtures :all
  before(:each) do
    @public_membership = memberships(:one)
    @private_membership = memberships(:two)
  end

  it "should join members and groups" do
    @group = Group.find(@public_membership.membershipable_id)
    @group.members.include?(@public_membership.member).should be_true
    @public_membership.member.groups.include?(@public_membership.group).should be_true
  end
  
  it "should not show private memberships in the groups and members list" do
    @group = Group.find(@private_membership.membershipable_id)
    @group.members.include?(@private_membership.member).should be_false
    @private_membership.member.groups.include?(@private_membership.group).should be_true
  end
end
