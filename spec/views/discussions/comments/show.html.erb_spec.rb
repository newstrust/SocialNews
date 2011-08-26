require File.dirname(__FILE__) + '/../../../spec_helper'

describe "discussions/comments/show.html.erb" do
  fixtures :all
  include CommentsHelper
  before do
    assigns[:current_member] = mock_model(Member, :has_role_or_above? => false, :can_comment? => true, :has_host_privilege? => false, :comments => mock(Array, :include? => false, :build => mock_comment(:commentable_id => 2, :initial_ancestor_id => 1, :body => '')), :flags => [], :terminated? => false)
    assigns[:comment] = mock_model(Comment, 
      :hidden? => false, 
      :visible? => true,
      :root => 1, 
      :commentable_type => 'Topic',
      :commentable_id => 1,
      :commentable => Topic.find(1), # SSS: Hmmm ...
      :likes => [],
      :ancestors => [],
      :children_count => 0,
      :parent => false ,
      :likes_count => 0,
      :all_children_count => 0, 
      :all_children => [],
      :children => [],
      :created_at => Time.now,
      :member => mock_member(:display_name => 'heavysixer', :image => nil),
      :body => '<script> bar </script>',
      :can_be_edited_by? => false
      )
  end

  it "should show the comment and sanitize the output" do
    render "/discussions/comments/show.html.erb"

    # now that the title was stripped only the word foo appears inside the title link.
    response.body.should =~ /&lt;script&gt; bar &lt;\/script&gt/
    response.should be_success
  end
end
