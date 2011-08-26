require File.dirname(__FILE__) + '/../spec_helper'

describe Partner do
  fixtures :all
  before(:each) do
    @partner = partners(:pledgie)
    @member = members(:heavysixer)
  end

  it "should be able to add and remove members" do
    lambda do
      @partner.members << @member
    end.should change(Membership, :count).by(1)
    @partner.reload.memberships_count.should == 1
    @partner.members.include?(@member).should be_true
    
    lambda do
      @partner.members.delete @member
    end.should change(Membership, :count).by(-1)
    @partner.reload.memberships_count.should == 0
    @partner.members.should be_empty
  end
  
  it "should not add the same member twice" do
   lambda do
     @partner.members << @member
   end.should change(Membership, :count).by(1)
   
   lambda do
     @partner.members << @member
   end.should_not change(Membership, :count)
  end
  
  it "should allow one partner with the same name per context" do
    lambda do
      @partner = Partner.create(:name => 'Huffington Post')
    end.should change(Partner, :count).by(1)
    
    lambda do
      @partner = Partner.create(:name => 'Huffington Post')
    end.should_not change(Partner, :count)
    @partner.errors.on(:name).should =~ /already been taken/
  end  
end
