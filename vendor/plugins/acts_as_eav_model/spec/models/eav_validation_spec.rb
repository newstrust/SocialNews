require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Validations on ActiveRecord Model annotated with 'has_eav_behavior'" do
  it "should execute as normal (validates_presence_of)" do
    post = Post.create :comment => 'No Intro', :teaser => 'This should fail'
    post.errors[:intro].should == "can't be blank"
  end
end