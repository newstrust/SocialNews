require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model annotated with 'has_eav_behavior' with no options in declaration" do
  it "should have many attributes" do
    Post.reflect_on_association(:post_attributes).macro.should == :has_many
  end
  
  it "should create new attribute on save" do
    p = Post.new :intro=>'Foo intro'
    p.new_attribute = 'new_value'
    new_attribute = p.post_attributes.detect {|a| a.name == 'new_attribute' }
    new_attribute.should_not be_nil
    new_attribute.value.should == 'new_value'
    p.new_attribute.should == 'new_value'
    p.save!
    p.reload
    p.new_attribute.should == 'new_value'
    new_attribute = PostAttribute.find_by_name_and_post_id('new_attribute', p.id)
    new_attribute.should_not be_nil
    new_attribute.value.should == 'new_value'
  end

  it "should delete attribute" do
    p = Post.create! :intro=>'Foo intro', :comment=>'this is a comment'
    p.post_attributes.size.should == 2
    p.comment = nil
    p.post_attributes.find_by_name('comment').should_not be_nil
    p.comment.should be_nil
    p.save!
    p.reload
    p.comment.should be_nil
    p.post_attributes.find_by_name('comment').should be_nil
  end
  
  it "should return nil when attribute does not exist" do
    p = Post.new :intro=>'Foo intro'
    p.not_exist.should be_nil
  end
  
  it "should read attributes using subscript notation" do
    p = Post.new :intro=>'We deliver quality foobars to consumers nationwide and around the globe',
                 :comment=>'Foo Bar Industries gets two thumbs up',
                 :teaser=>'Coming October 7, the foobarantator'
    p['comment'].should == 'Foo Bar Industries gets two thumbs up'
    p['intro'].should == 'We deliver quality foobars to consumers nationwide and around the globe'
    p['teaser'].should == 'Coming October 7, the foobarantator'
  end
end
