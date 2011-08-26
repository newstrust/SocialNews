require File.dirname(__FILE__) + '/../spec_helper'

describe NotificationMailer do
  fixtures :all

  app_domain = SocialNewsConfig["app"]["domain"]
  app_name   = SocialNewsConfig["app"]["name"]

  before(:each) do
    @member = members(:heavysixer)
    @member.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  it "should deliver an email when someone flags a comment" do
    @legacy = members(:legacy_member)
    @m = members(:heavysixer)
    [Story, Topic, Source, Subject].each_with_index do |klass, index|
      @record = klass.send(:first)
      @record.add_host(@m) if @record.respond_to?(:hosts)
      @record.update_attribute(:allow_comments, true) if @record.attributes.keys.include?('allow_comments')
      @comment = @record.comments.create(:body => 'some comment', :member_id => @member.id)
      @legacy.flags.create :flaggable => @comment, :reason => 'flag'

      # Subjects don't show their controller so we need to omit it here.
      controller_name = klass != Subject ? klass.to_s.downcase.pluralize + '/' : ''
      record_param = klass != Subject ? @record.to_param : @record.slug
      ActionMailer::Base.deliveries.size.should be(1)
      ActionMailer::Base.deliveries.first.from.last.should == SocialNewsConfig["email_addrs"]["support"]
      ActionMailer::Base.deliveries.first.subject.should == Mailer::SUBJECT_PREFIX + "[#{app_name.upcase} FLAGGED CONTENT]"
      ActionMailer::Base.deliveries.last.to.first.should == "comments@#{app_domain}"
      if @record.respond_to?(:hosts)
        ActionMailer::Base.deliveries.last.to.include?(@m.email).should be_true
      end
      ActionMailer::Base.deliveries.last.body.should =~ /Total Flags Received: #{index+1}/
      ActionMailer::Base.deliveries.last.body.should =~ /Total Flags Given: #{index+1}/
      ActionMailer::Base.deliveries.last.body.should =~ /Permalink: http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@comment.id}/
      ActionMailer::Base.deliveries.last.body.should =~ /Offending Member:\n  Name: #{@member.display_name}/
      ActionMailer::Base.deliveries.last.body.should =~ /Reporting Member:\n  Name: #{@legacy.display_name}/
      ActionMailer::Base.deliveries.last.body.should =~ /ID: #{@legacy.id}/
      ActionMailer::Base.deliveries = []
    end
  end

  it "should deliver an email when someone likes a comment" do
    @legacy = members(:legacy_member)
    [Story, Topic, Source, Subject].each_with_index do |klass, index|
      @record = klass.send(:first)
      @record.update_attribute(:allow_comments, true) if @record.attributes.keys.include?('allow_comments')
      @comment = @record.comments.create(:body => 'some comment', :member_id => @member.id)
      @comment.member.email_notification_preferences.comment_liked.should be_true
      @flag = @legacy.flags.create :flaggable => @comment, :reason => 'like'

      # Subjects don't show their controller so we need to omit it here.
      controller_name = klass != Subject ? klass.to_s.downcase.pluralize + '/' : ''
      record_param = klass != Subject ? @record.to_param : @record.slug
      ActionMailer::Base.deliveries.size.should be(1)
      ActionMailer::Base.deliveries.first.from.last.should == SocialNewsConfig["email_addrs"]["support"]
      ActionMailer::Base.deliveries.first.subject.should == "#{@legacy.display_name} likes your comment on #{app_name}"
      ActionMailer::Base.deliveries.last.to.first.should == @comment.member.email
      ActionMailer::Base.deliveries.last.body.should =~ /http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@comment.id}/
      ActionMailer::Base.deliveries = []
    end

    # Mark this user as someone who doesn't want to recievce updates when their comment is replied to.
    @prefs = @comment.member.email_notification_preferences
    ActionMailer::Base.deliveries = []
    @prefs.comment_liked = false
    @comment.member.send(:write_attribute, :email_notification_preferences, @prefs)
    @comment.member.save

    @flag.destroy
    @member.flags.create :flaggable => @comment, :reason => 'like'
    ActionMailer::Base.deliveries.size.should be(0)
  end

  it "should send an email to a member when their comment receives a reply" do
    @s = Story.first
    @legacy = members(:legacy_member)
    @comment = comments(:child)
    @m = @comment.member
    @m.email_notification_preferences.comment_replied_to.should be_true
    lambda do
      @new_comment = Comment.create(:member_id => @legacy.id, :body => 'foo', :commentable_type => 'Story', :commentable_id => @s.id, :initial_ancestor_id => @comment.id)
    end.should change(Comment, :count).by(1)
    @new_comment.deliver_notifications()

    ActionMailer::Base.deliveries.size.should be(2)
    ActionMailer::Base.deliveries.last.from.last.should == SocialNewsConfig["email_addrs"]["support"]
    ActionMailer::Base.deliveries.last.subject.should == "#{@legacy.display_name} replied to your comment on #{app_name}"
    ActionMailer::Base.deliveries.last.to.first.should == @m.email
    ActionMailer::Base.deliveries.last.body.should =~ /http:\/\/localhost:3000\/stories\/#{@s.to_param}#p-#{@new_comment.id}/
    ActionMailer::Base.deliveries = []

    # Should not send a message if they don't want to know about replies.
    @prefs = @m.email_notification_preferences
    ActionMailer::Base.deliveries = []
    @prefs.comment_replied_to = false
    @m.send(:write_attribute, :email_notification_preferences, @prefs)
    @m.save
    lambda do
      @new_comment = Comment.create(:member_id => @legacy.id, :body => 'foo', :commentable_type => 'Story', :commentable_id => @s.id, :initial_ancestor_id => @comment.id)
    end.should change(Comment, :count).by(1)
    @new_comment.deliver_notifications()
    ActionMailer::Base.deliveries.size.should be(1)
  end

  it "should send an email to all siblings when someone replies to a comment" do
    @legacy = members(:legacy_member)
    @trusted_member = members(:trusted_member)
    [Story, Topic, Source, Subject].each_with_index do |klass, index|
      @record = klass.send(:first)
      @record.update_attribute(:allow_comments, true) if @record.attributes.keys.include?('allow_comments')
      @comment = @record.comments.create(:body => 'some comment', :member_id => @member.id)
      @comment.member.email_notification_preferences.comment_replied_to.should be_true
      [@legacy, @trusted_member].each do |member|
        @reply_comment = @record.comments.new(:body => 'some comment', :member_id => member.id)
        @reply_comment.initial_ancestor_id = @comment.id
        @reply_comment.save
        @reply_comment.nest_inside(@comment.id)
      end
      @reply_comment.deliver_notifications

      # Subjects don't show their controller so we need to omit it here.
      controller_name = klass != Subject ? klass.to_s.downcase.pluralize + '/' : ''
      record_param = klass != Subject ? @record.to_param : @record.slug

      # We should get at least three emails here
      ActionMailer::Base.deliveries.size.should be(3)

      # The first is the NT moderators
      ActionMailer::Base.deliveries[0].to.first.should == "comments@#{app_domain}"
      ActionMailer::Base.deliveries[0].subject.should == "New #{klass.to_s.downcase} comment on #{app_name}"

      # The second is the parent comment author
      ActionMailer::Base.deliveries[1].to.first.should == @comment.member.email
      ActionMailer::Base.deliveries[1].subject.should == "#{@trusted_member.display_name} replied to your comment on #{app_name}"
      ActionMailer::Base.deliveries[1].body.should =~ /replied to your comment/
      ActionMailer::Base.deliveries[1].body.should =~ /http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@reply_comment.id}/

      # The remaining comments go to siblings of the newly created comment.
      ActionMailer::Base.deliveries[2].to.first.should == @legacy.email
      ActionMailer::Base.deliveries[2].subject.should == "#{@trusted_member.display_name} also replied to a comment by #{@comment.member.display_name} on #{app_name}"
      ActionMailer::Base.deliveries[2].body.should =~ /replied to a comment/
      ActionMailer::Base.deliveries[2].body.should =~ /http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@reply_comment.id}/
      ActionMailer::Base.deliveries = []
    end
  end

  it "if a member both likes and replied to a comment they should only get one email" do
    @record = Story.first
    @legacy = members(:legacy_member)
    @trusted_member = members(:trusted_member)
    lambda do
      @parent = @record.comments.create(:body => 'some comment', :member_id => @legacy.id)
    end.should change(Comment, :count).by(1)

    # Member likes and replies to the comment.
    @members_flag = @member.flags.create :flaggable => @parent, :reason => 'like'
    lambda do
      @members_comment = @record.comments.new(:body => 'some comment', :member_id => @member.id)
      @members_comment.initial_ancestor_id = @parent.id
      @members_comment.save
      @members_comment.nest_inside(@parent.id)
    end.should change(Comment, :count).by(1)

    # Someone else now makes a comment, and @member should only get one email.
    @reply_comment = @record.comments.new(:body => 'some comment', :member_id => @trusted_member.id)
    @reply_comment.initial_ancestor_id = @parent.id
    @reply_comment.save
    @reply_comment.nest_inside(@parent.id)

    @reply_comment.notification_list[:likes].include?(@member).should be_true
    @reply_comment.notification_list[:replies].include?(@member).should be_true

    # Clear the emails generated by AfterFlag and comment creations because we are not testing them here.
    ActionMailer::Base.deliveries = []
    @reply_comment.deliver_notifications

    # We should get at least three emails here
    ActionMailer::Base.deliveries.size.should be(3)

    # The first is the NT moderators
    ActionMailer::Base.deliveries[0].to.first.should == "comments@#{app_domain}"
    ActionMailer::Base.deliveries[0].subject.should == "New #{@record.class.to_s.downcase} comment on #{app_name}"

    # The second is the parent comment author
    ActionMailer::Base.deliveries[1].to.first.should == @parent.member.email
    ActionMailer::Base.deliveries[1].subject.should == "#{@trusted_member.display_name} replied to your comment on #{app_name}"
    ActionMailer::Base.deliveries[1].body.should =~ /replied to your comment/
    ActionMailer::Base.deliveries[1].body.should =~ /http:\/\/localhost:3000\/stories\/#{@record.to_param}#p-#{@reply_comment.id}/

    # The remaining comments go to anyone who liked the comment
    ActionMailer::Base.deliveries[2].to.first.should == @member.email
    ActionMailer::Base.deliveries[2].subject.should == "#{@trusted_member.display_name} also replied to a comment by #{@legacy.display_name} on #{app_name}"
    ActionMailer::Base.deliveries[2].body.should =~ /http:\/\/localhost:3000\/stories\/#{@record.to_param}#p-#{@reply_comment.id}/
    ActionMailer::Base.deliveries = []
  end

  it "should send an email to any member who likes a comment that receives a reply" do
    @legacy = members(:legacy_member)
    @trusted_member = members(:trusted_member)
    [Story, Topic, Source, Subject].each_with_index do |klass, index|
      @record = klass.send(:first)
      @record.update_attribute(:allow_comments, true) if @record.attributes.keys.include?('allow_comments')
      @comment = @record.comments.create(:body => 'some comment', :member_id => @member.id)
      @comment.member.email_notification_preferences.comment_replied_to.should be_true
      [@trusted_member].each do |member|
        @flag = @legacy.flags.create :flaggable => @comment, :reason => 'like'
        @reply_comment = @record.comments.new(:body => 'some comment', :member_id => member.id)
        @reply_comment.initial_ancestor_id = @comment.id
        @reply_comment.save
        @reply_comment.nest_inside(@comment.id)
      end

      # Clear the emails generated by AfterFlag because we are not testing them here.
      ActionMailer::Base.deliveries = []
      @reply_comment.deliver_notifications

      # Subjects don't show their controller so we need to omit it here.
      controller_name = klass != Subject ? klass.to_s.downcase.pluralize + '/' : ''
      record_param = klass != Subject ? @record.to_param : @record.slug

      # We should get at least three emails here
      ActionMailer::Base.deliveries.size.should be(3)

      # The first is the NT moderators
      ActionMailer::Base.deliveries[0].to.first.should == "comments@#{app_domain}"
      ActionMailer::Base.deliveries[0].subject.should == "New #{klass.to_s.downcase} comment on #{app_name}"

      # The second is the parent comment author
      ActionMailer::Base.deliveries[1].to.first.should == @comment.member.email
      ActionMailer::Base.deliveries[1].subject.should == "#{@trusted_member.display_name} replied to your comment on #{app_name}"
      ActionMailer::Base.deliveries[1].body.should =~ /replied to your comment/
      ActionMailer::Base.deliveries[1].body.should =~ /http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@reply_comment.id}/

      # The remaining comments go to anyone who liked the comment
      ActionMailer::Base.deliveries[2].to.first.should == @legacy.email
      ActionMailer::Base.deliveries[2].subject.should == "#{@trusted_member.display_name} replied to a comment you like on #{app_name}"
      ActionMailer::Base.deliveries[2].body.should =~ /http:\/\/localhost:3000\/#{controller_name}#{record_param}#p-#{@reply_comment.id}/
      ActionMailer::Base.deliveries = []
    end
  end
end
