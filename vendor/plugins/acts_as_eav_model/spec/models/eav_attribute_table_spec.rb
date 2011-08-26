require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model annotated with 'has_eav_behavior' with an existing attribute table" do
  it 'should be possible to drop attribute table' do
    Post.drop_attribute_table
    ActiveRecord::Base.connection.tables.detect {|t| t.to_s == 'post_attributes'}.should be_nil
  end
  
  it 'should be possible to recreate attribute table' do
    Post.create_attribute_table
    ActiveRecord::Base.connection.tables.detect {|t| t.to_s == 'post_attributes' }.should_not be_nil
  end
  
  it 'should not be reloadable' do
    PostAttribute.reloadable?.should == false
  end
end