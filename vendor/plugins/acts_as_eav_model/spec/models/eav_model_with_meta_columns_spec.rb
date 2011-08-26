require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model annotated with 'has_eav_behavior' with meta_columns option specified" do
  it 'should enable meta information on attributes' do
    u = User.create! :email=>'example@example.com', :email_private=>false
    u.email_private.should == false
    u.user_attributes.size.should == 1
    attr = u.user_attributes.first
    attr.value.should == 'example@example.com'
    attr.private.should == false
  end
  
  it 'should respect defaults' do
    u = User.new :email=>'example@example.com'
    u.email_private.should == true
  end
end