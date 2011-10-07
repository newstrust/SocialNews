require File.dirname(__FILE__) + '/../spec_helper'

describe Comment do
  fixtures :all
  before(:each) do
    @comment = Comment.new
    @member = members(:heavysixer)
    @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
  end

  it 'should allow members to create comments' do
    lambda do
      @comment = Comment.create(:body => 'foo')
    end.should_not change(Comment, :count)
    @comment.errors.on(:member_id).should_not be_nil

    lambda do
      lambda do
        @member.comments.create(:body => 'awesome')
      end.should change(Comment, :count).by(1)
    end.should change(@member.comments, :size).by(1)
    @member.reload
    @member.total_meta_comments.should == 1
    @member.comments.first.destroy
    @member.reload
    @member.total_meta_comments.should == 0
  end

  it "should allow a member to edit a comment up to 30 minutes before it is locked" do
    lambda do
      @comment = @member.comments.create(:body => 'awesome')
    end.should change(Comment, :count).by(1)
    @comment.editable?.should be_true
    @comment.editable_time_left.should == 30
    @comment.updated_at = 1.hour.ago
    @comment.editable?.should be_false
    @comment.editable_time_left.should == -30
  end

  it "should not allow members with a low status to make comments" do
    lambda do
      @member.comments.create(:body => 'awesome')
    end.should change(Comment, :count)
    @member.update_attribute(:validation_level, 0)
    lambda do
      @comment = @member.comments.create(:body => 'awesome')
    end.should_not change(Comment, :count)
    @comment.errors.on(:base).should == "There was an error saving your comment"    
  end

  it "should not allow muzzled members to make comments" do
    lambda do
      @member.comments.create(:body => 'awesome')
    end.should change(Comment, :count)
    @member.update_attribute(:muzzled, true)
    @member.muzzled?.should be_true
    lambda do
      @comment = @member.comments.create(:body => 'awesome')
    end.should_not change(Comment, :count)
    @comment.errors.on(:base).should == "There was an error saving your comment"
  end

  it 'should be able to find only top level visible comments' do
    @comments  = Comment.top.visible.find(:all)
    @comments.size.should == 1
    @comments.first.id.should == comments(:parent).id
  end

  it 'should allow A comment to have many replies' do
    @comment = comments(:parent)
    @comment.replies.first.id.should == comments(:child).id
  end

  it "should be able to notify the siblings of a comment's replies using the notification_list when a new reply is created" do
    @m = members(:heavysixer)
    @parent = comments(:parent)
    @comment = comments(:child)
    @new_reply = Comment.create(:initial_ancestor_id => @parent.id, :body => 'new reply', :member_id => 16)
    @new_reply.notification_list[:replies].should eql([@comment.member])
    @prefs = Member::Preferences.new

    # Mark this user as someone who doesn't want to recievce updates when their comment is replied to.
    @prefs.replied_comment_replied_to = false
    @m.send(:write_attribute, :email_notification_preferences, @prefs)
    @m.save
    @m.reload
    @m.email_notification_preferences.replied_comment_replied_to.should be_false
    @new_reply.notification_list[:replies].should be_empty

    # Should notify anyone who liked the parent comment
    @flag = @m.flags.create(:flaggable => @parent, :reason => 'like')
    @parent.likes_count.should == 1
    @new_reply.notification_list[:likes].should eql([@m])
  end

  it "should automattically load the commentable class if available" do
    lambda do
      @comment = Comment.create(:body => 'foo', :member_id => @member.id)
    end.should change(Comment, :count).by(1)
    @comment.commentable.should be_nil

    # If the class cannot be found rescue and return nil
    @comment.update_attributes(:commentable_type => 'foo', :commentable_id => '1')
    @comment.commentable.should be_nil
  end

  it 'should allow a comment to be manually nested inside another' do
    @parent = comments(:parent)
    lambda do
      @comment = Comment.create(:body => 'foo', :member_id => @member.id)
    end.should change(Comment, :count).by(1)
    @comment.parent_id.should be_nil
    @comment.nest_inside(@parent.id)
    @comment.parent_id.should_not be_nil
    
    @comment.parent_id.should == @parent.id
  end

  it "should automatically nest a comment inside another if the ancestor_id is supplied" do
    @parent = comments(:parent)
    lambda do
      @comment = Comment.create(:body => 'foo', :member_id => @member.id, :initial_ancestor_id => @parent.id)
    end.should change(Comment, :count).by(1)
    @comment.parent_id.should_not be_nil
    @comment.parent_id.should == @parent.id
  end

  it "should strip HTML from the body but leave textile" do
    @comment = @member.comments.create(:body => "h1. <b>foo</b>")
    @comment.body.should == "<h1>foo</h1>"
  end

  it "should strip HTML from the title" do
    @comment = @member.comments.create(:title => "<b>foo</b>")
    @comment.title.should == "foo"
  end

  it "should limit the character count for the comment body" do
    lambda do
      body = ''
      2001.times { body << '.' }
      @comment = Comment.create(:body => body, :member_id => @member.id)
    end.should_not change(Comment, :count)
    @comment.errors.on(:body_plain).should =~ /Responses must be 2000 characters or less./
  end

  it "should show only visible children" do
    @comment = comments(:parent)
    @comment.all_children.size.should == 1
    @comment.all_visible_children.size.should == 1
    @comment.children.first.update_attribute(:hidden,true)
    @comment.all_visible_children.size.should == 0
  end

  it 'should allow edits by certain members other than the author' do
    @new_member = mock_member(:id => 200)
    @comment = comments(:parent)

    # Nil users cannot edit
    @comment.can_be_edited_by?.should be_false

    # Normal members cannot edit.
    @new_member.stub!(:has_role_or_above?).and_return(false)
    @comment.can_be_edited_by?(@new_member).should be_false

    # Some admin can edit
    @new_member.stub!(:has_role_or_above?).and_return(true)
    @comment.can_be_hidden_by?(@new_member).should be_true

    # The comment author can edit the comment.
    @new_member.stub!(:has_role_or_above?).and_return(false)
    @new_member.stub!(:id).and_return(@comment.member_id)
    @comment.can_be_edited_by?(@new_member).should be_true
  end

  it "should allow comments to be affixed to a model by specifying a commentable_type" do
    @s = Source.first
    @s.update_attribute(:allow_comments,true)
    @t = Topic.first
    @t.update_attribute(:allow_comments,true)
    lambda do
      @c = @s.comments.create(:body => 'some comment', :member_id => @member.id)
      @d = @t.comments.create(:body => 'some comment', :member_id => @member.id)

      @d.commentable_type.should == 'Topic'

      # Yet it should still be able to be found through the association proxy
      @t.comments(true).first.id.should == @d.id
    end.should change(Comment, :count).by(2)
  end

  it "comments should not save if a commentable model instance forbids it" do
    @s = Source.first
    @s.update_attribute(:allow_comments, false).should be_true
    m = members(:legacy_member)
    lambda do
      @s.comments.create(:body => 'some comment', :member_id => @member)
    end.should_not change(Comment, :count)
  end
end
