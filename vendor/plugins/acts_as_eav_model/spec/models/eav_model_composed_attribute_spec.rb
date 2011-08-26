require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model annotated with 'has_eav_behavior' with a composed attribute" do
  it 'should persist multiparam assignment to attribute model' do
    u = User.create!
    u.attributes = { 'foo_multiple(1i)'=>'2', 'foo_multiple(2i)'=>'2' }
    u.foo_multiple.should == Multiple.new(2, 2)
    u.foo.to_s.should == '4'
    u.foo_multiplyer.should == 2
    u.save!
    u.reload
  end
  
  it 'should raise exception on invalid multiparams' do
    u = User.create!
    lambda { u.attributes = { 'foo_multiple(1i)'=>'2' } }.should raise_error(ActiveRecord::MultiparameterAssignmentErrors)
  end
  
  it 'should nil composed attribute when setting blank values' do
    u = User.create!
    u.update_attributes 'foo_multiple(1i)'=>'2', 'foo_multiple(2i)'=>'2'
    u.reload
    u.foo_multiple.should_not be_nil
    u.attributes = { 'foo_multiple(1i)'=>'', 'foo_multiple(2i)'=>'' }
    u.foo_multiple.should be_nil
  end
end