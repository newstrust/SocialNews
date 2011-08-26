require File.dirname(__FILE__) + '/../spec_helper'

module NewsletterMassMailerSpecHelper
  def to_id_array(object_array)
    object_array.map(&:id)
  end
end

describe NewsletterMassMailer do
  include NewsletterMassMailerSpecHelper
  fixtures :all

  before(:each) do
      # Note that the mass mailer uses SMTP ... so, we need to set perform-deliveries to false so that mails don't actually go out!
    ActionMailer::Base.perform_deliveries = false
    @m1 = members(:legacy_member)        ## (daily, weekly, format) = (t, f, html)
    @m2 = members(:heavysixer)           ## (daily, weekly, format) = (f, t, text)
    @m3 = members(:heavysixers_friend)   ## (daily, weekly, format) = (f, f, _)
    @m4 = members(:all_newsletters_html) ## (daily, weekly, format) = (t, t, html)
    @all_members = [@m1, @m2, @m3, @m4]
    @all_members.each { |m| m.update_attribute(:status, 'member') }
    @daily = newsletters(:daily_auto)
    @weekly = newsletters(:weekly_ready)
    NewsletterRecipient.delete_all

      # To avoid having to require a live smtp connection, create a mock!
    Net::SMTP.stub!(:start).and_yield(mock_smtp)
  end

  it "should not send anything if there isn't any newsletter ready" do
    @daily.state = Newsletter::NEW
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array(@all_members))
    NewsletterRecipient.count.should == 0
  end

  it "should not send newsletters to those who don't want it" do
    @daily.state = Newsletter::READY
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m3]))
    NewsletterRecipient.count.should == 0
  end

  it "should not send newsletters to members with 'guest' status" do
    @m1.update_attribute(:status, 'guest')
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m4]))
    NewsletterRecipient.count.should == 1
  end

  it "should not send newsletters to members with 'suspended' status" do
    @m1.update_attribute(:status, 'suspended')
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m4]))
    NewsletterRecipient.count.should == 1
  end

  it "should send newsletters to members with 'duplicate' status" do
    @m1.update_attribute(:status, 'duplicate')
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m4]))
    NewsletterRecipient.count.should == 2
  end

  it "should send newsletters to everyone who wants one" do
    @daily.state = Newsletter::READY
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array(@all_members))
    NewsletterRecipient.count.should == 2

    @weekly.state = Newsletter::READY
    @weekly.save
    NewsletterMassMailer.dispatch_to(Newsletter::WEEKLY, to_id_array(@all_members))
    NewsletterRecipient.count.should == 4
  end

    ## Not possible to test this without delivering something -- but cannot
    ## do dummy deliveries with the newsletter mass mailer because it uses
    ## SMTP in the code directly.  To test, we need to save something in
    ## the DB even for blocked emails ... will consider this later.
  it "should send newsletters in the format that a user wants it"

  it "should not send duplicates even if recipients are repeated" do
    @daily.state = Newsletter::READY
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m1]))
    NewsletterRecipient.count.should == 1
  end

  it "should resume cleanly from interrupted sends without sending duplicates" do
      ## Simulate an interrupt
    @daily.state = Newsletter::READY
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m2]))
    NewsletterRecipient.count.should == 1

      ## Resend newsletter to everyone
    @daily.state = Newsletter::IN_TRANSIT
    @daily.save
    NewsletterMassMailer.dispatch_to(Newsletter::DAILY, to_id_array([@m1, @m2, @m3, @m4]))
    NewsletterRecipient.count.should == 2
  end

  it "should send mynews emails if the list of stories is not empty" do
    story = stories(:legacy_story)
    [@m2, @m4].each { |m| m.add_newsletter_subscription(Newsletter::MYNEWS); FollowedItem.toggle(m.id, 'source', story.primary_source_id) }
    Story.stub!(:list_stories_with_associations).and_return([Story.find(1)])

    Newsletter.fetch_latest_newsletter(Newsletter::MYNEWS, Member.nt_bot)
    NewsletterMassMailer.dispatch_to(Newsletter::MYNEWS, to_id_array([@m1, @m2, @m3, @m4]))
    NewsletterRecipient.count.should == 2
  end

  it "should not send mynews emails if the list of stories is empty" do
    story = stories(:legacy_story)
    [@m2, @m4].each { |m| m.add_newsletter_subscription(Newsletter::MYNEWS); FollowedItem.toggle(m.id, 'source', story.primary_source_id) }
    Story.stub!(:list_stories_with_associations).and_return([])

    Newsletter.fetch_latest_newsletter(Newsletter::MYNEWS, Member.nt_bot)
    NewsletterMassMailer.dispatch_to(Newsletter::MYNEWS, to_id_array([@m1, @m2, @m3, @m4]))
    NewsletterRecipient.count.should == 0
  end
end
