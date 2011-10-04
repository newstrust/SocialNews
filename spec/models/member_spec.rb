require File.dirname(__FILE__) + '/../spec_helper'

module MemberSpecHelper
  def valid_member_attributes
    { :email => "new_guy@internet.com",
      :name => "New Guy",
      :password => "some_pass",
      :password_confirmation => "some_pass"}
  end
end

describe Member do
  include AuthenticatedTestHelper
  include MemberSpecHelper
  fixtures :all

  describe 'being updated' do
    before(:each) do
      @member  = members(:heavysixer)
    end

    # This test is no longer relevant. Removed 'Provisional' from available options. Commenting out!
    # it 'should update the status' do
    #   @statuses = Array.new(Member.status_choices)
    #   @statuses.delete('Provisional')
    #   @old_status = 'Provisional' # This is the default state.
    #   @statuses.each do |new_status|
    #     proc{
    #       @member.update_attribute(:status, new_status)
    #       @member.reload
    #     }.should change(@member, :status).from(@old_status).to(new_status)
    #     @old_status = new_status
    #   end
    # end
    
    it 'should not update unless the status is an available choice' do
      @member.status = "foo"
      @member.save.should be_false
      @member.errors_on(:status).first.should == "This is not an available choice."
    end
    
    # This test is not needed. Now allowing admin to change member.status
    # via the member profile edit form.
    # it 'should not allow status to be updated through mass assignment' do
    #   proc {
    #     @member.update_attributes(:status => Member.status_choices.last)
    #     @member.reload
    #   }.should_not change(@member, :status)
    # end
  end
  
  it "should allow the member to set a variety of email notification preferences" do
    @keys = [:comment_liked, :comment_replied_to, :liked_comment_replied_to, :submitted_story_reviewed, :reviewed_story_reviewed, :liked_story_reviewed, :followed_member]
    (@m = members(:legacy_member)).save
    @prefs  = @m.email_notification_preferences
    @keys.each do |key|
      @m.email_notification_preferences.send(key).should be_true
      @prefs.instance_variable_set("@#{key.to_s}", false)
    end
    @m.send(:write_attribute, :email_notification_preferences, @prefs)
    @m.save
    @keys.each do |key|
      @m.email_notification_preferences.send(key).should be_false
    end
  end
  
  describe 'being activated' do
    it 'should remove the activation key and update the status' do
      reviewed_story = Story.find(reviews(:unactivated_member_review).story_id)
      before_count = reviewed_story.reviews_count

      @member = members(:heavysixers_friend)
      code = @member.activation_code
      proc {
        proc {
          proc {
            @member.activate
          }.should change(@member, :activation_code).from(code).to(nil)
        }.should change(@member, :status).from('guest').to('member')
      }.should change(@member, :total_reviews).by(2)
      
      # member's reviews & submitted stories should be updated, too
      reviews(:unactivated_member_review).reload.status.should == "list"
      stories(:hidden_story).status.should == "list"

      # reviews_count for stories reviewed by this member should be incremented
      reviewed_story.reload.reviews_count.should == before_count + 1
    end
  end

  describe 'being created' do
    before do
      @member = nil
      @creating_member = lambda do
        @member = create_member
        violated "#{@member.errors.full_messages.to_sentence}" if @member.new_record?
      end
    end
    
    it 'increments User#count' do
      @creating_member.should change(Member, :count).by(1)
    end
    
    it 'initializes #activation_code' do
      @creating_member.call
      @member.reload
      @member.activation_code.should_not be_nil
    end
  end
  
  describe 'being created by another member' do
    before(:each) do
      @member = members(:heavysixer)
    end
    
    it 'should only require an email address' do
      @member.rating = 5
      @member.save.should be_true
      
      # Email required
      lambda do
        lambda do
          @new_member = Member.create_through_member_referral(@member)
        end.should raise_error(ArgumentError)
      end.should_not change(Member, :count)
      
      lambda do
        @new_member = Member.create_through_member_referral(@member, 'foo@baz.com')
      end.should change(Member, :count).by(1)
      @new_member.referring_member = @member
      @new_member.validation_level.should == @member.rating
    end
    
    it 'should not create a member if one already exists for that email' do
      lambda do
        lambda do
          @new_member = Member.create_through_member_referral(@member, @member.email)
        end.should raise_error(ActiveRecord::StatementInvalid)
      end.should_not change(Member, :count)
    end
    it 'the invite status should show up for the referring member'
    it "should email the member who created the invite when their friend signs up"
  end
  
  describe 'accepting an invitation from a partner' do
    fixtures :all
    before(:each) do
      @m1 = members(:heavysixer)
      @partner = partners(:pledgie)
      @invite = @partner.invitations.first
    end
    
    it "should accept an invite from a partner" do
      @m1.accept_invitation(@invite)
      @m1.invitation.should == @invite
      @m1.validation_level.should == @invite.validation_level
      @m1.invitation_code.should == @invite.code
    end
  end

  describe 'being suspended' do
    before(:each) do
      @m1 = members(:legacy_member)
      @m1.is_public?.should == true
      @m1.reviews.length.should > 0
      @expected_reviews_count = @m1.reviews.collect { |r| Story.find(r.story_id).reviews_count - 1}
    end

    it "should apply the muzzle to the member" do
      @m = members(:legacy_member)
      @m.muzzled?.should be_false
      @m.update_attribute(:muzzled,true)
      @m.muzzled?.should be_true
    end

    it "should only allow you to comment if not muzzled and have the appropriate status" do
      @m = members(:legacy_member)
      @m.can_comment?.should be_true
      @m.muzzled = true
      @m.can_comment?.should be_false
      @m.muzzled = false
      @m.can_comment?.should be_true
      @m.status = "suspended"
      @m.can_comment?.should be_false
      @m.status = "duplicate"
      @m.can_comment?.should be_false
      @m.status = "terminated"
      @m.can_comment?.should be_false
    end

    it "should have flags and flaggings" do
      @m = members(:legacy_member)
      @h = members(:heavysixer)
      @h.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @c = @h.comments.create(:body => 'foo')
      lambda do
        @like = @m.flags.create(:flaggable_type => 'Comment', :flaggable_id => @c.id, :reason => 'like')
        @flag = @m.flags.create(:flaggable_type => 'Comment', :flaggable_id => @c.id, :reason => 'flag')
      end.should change(Flag, :count).by(2)
      @m.flags.include?(@flag).should be_true
      @m.flags.include?(@like).should be_true
      @m.likes.include?(@like).should be_true
      @m.flags_count.should == 1
      @h.flaggings.include?(@flag).should be_true
      @h.likings.include?(@like).should be_true
      @h.likings_count.should == 1
      @m.likes_count.should == 1
    end
    
    it "should muzzle the members comments when the member is muzzled" do
      @m = members(:legacy_member)
      @m.update_attribute(:validation_level, SocialNewsConfig["min_validation_level_for_comments"])
      @c = @m.comments.create(:body => 'foo')
      @c.hidden_through_muzzle.should be_false

      @m.update_attribute(:muzzled, true)
      @c.reload.hidden_through_muzzle.should be_true

      @m.update_attribute(:muzzled, false)
      @c.reload.hidden_through_muzzle.should be_false
    end

    it 'should update reviews_count for reviewed stories' do
      @m1.status = 'duplicate'
      @m1.save!

      @m1.reload.reviews.length.should > 0
      reviewed_stories_reviews_count_after = @m1.reload.reviews.collect { |r| Story.find(r.story_id).reviews_count }
      reviewed_stories_reviews_count_after.should == @expected_reviews_count
    end

    it 'should not change reviews_count for reviewed stories when reviews have been hidden' do
        # Hide one of the reviews before suspending the member
      r1 = @m1.reviews[0]
      r1.status = 'hide'
      r1.save!
      r1_story_reviews_count_before_suspend = Story.find(r1.story_id).reviews_count

        # Suspend the member
      @m1.status = 'duplicate'
      @m1.save!

      @m1.reload.reviews.length.should > 0
      reviewed_stories_reviews_count_after = @m1.reload.reviews.collect { |r| Story.find(r.story_id).reviews_count }

        # Ensure that the new reviews count accounts for the hidden review!
        # The reviews_count for that story shouldn't have changed!
      reviewed_stories_reviews_count_after[0].should == r1_story_reviews_count_before_suspend

        # but, the final tally should still match the expected reviews count!
        # (because when the review was hidden, the story's reviews_count would have been decremented)
      reviewed_stories_reviews_count_after.should == @expected_reviews_count
    end

    it 'should not change reviews_count for reviewed stories when reviews have non-ratable disclosures' do
        # Hide one of the reviews before suspending the member
      r1 = @m1.reviews[0]
      r1.disclosure = 'author'
      r1.save!
      r1_story_reviews_count_before_suspend = Story.find(r1.story_id).reviews_count

        # Suspend the member
      @m1.status = 'duplicate'
      @m1.save!

      @m1.reload.reviews.length.should > 0
      reviewed_stories_reviews_count_after = @m1.reload.reviews.collect { |r| Story.find(r.story_id).reviews_count }

        # Ensure that the new reviews count accounts for the non-ratable review!
        # The reviews_count for that story shouldn't have changed!
      reviewed_stories_reviews_count_after[0].should == r1_story_reviews_count_before_suspend

        # but, the final tally should still match the expected reviews count!
        # (because when the review ended up being non-ratable, the story's reviews_count would have been decremented)
      reviewed_stories_reviews_count_after.should == @expected_reviews_count
    end

    it 'should remove all items followed by this member and all items where this member is followed' do
      @m2 = members(:heavysixers_friend)
      FollowedItem.add_follow(@m1.id, 'Source', Source.find(:first).id)
      @m1.reload.followed_items.count.should == 1

      FollowedItem.add_follow(@m2.id, 'Source', Source.find(:first).id)
      FollowedItem.add_follow(@m2.id, 'Member', @m1.id)
      @m2.reload.followed_items.count.should == 2

      @m1.update_attribute(:status, Member::TERMINATED)
      @m1.reload.followed_items.count.should == 0
      @m2.reload.followed_items.count.should == 1
    end
  end

  describe 'unsubscribing from newsletters' do
    before(:each) do
      @m1 = members(:heavysixer)
      @m2 = members(:heavysixers_friend)
    end

    it 'should compute valid unsubscribe keys' do
      k1 = @m1.newsletter_unsubscribe_key(nil)
      k1.should_not be_nil
      Member.get_unsubscribing_member(k1).should == @m1
    end

    it 'should provide different unsubscribe keys for different members' do
      @m1.newsletter_unsubscribe_key(nil).should_not == @m2.newsletter_unsubscribe_key(nil)
    end

    it 'should return nil if provided an invalid unsubscribe key' do
      Member.get_unsubscribing_member("164:384ac8d").should be_nil
    end
  end

  it 'strips leading/trailing white space' do
    @m1 = members(:heavysixer)
    @m1.email = " #{@m1.email} "
    @m1.name = " #{@m1.name} "
    @m1.save!
    @m1.reload
    (@m1.email =~ /(^\s)|(\s$)/).should be_nil
    (@m1.name =~ /(^\s)|(\s$)/).should be_nil
  end
  
  it 'requires password' do
    lambda do
      u = create_member(:password => nil)
      u.errors.on(:password).should_not be_nil
    end.should_not change(Member, :count)
  end

  it 'requires password confirmation' do
    lambda do
      u = create_member(:password_confirmation => nil)
      u.errors.on(:password_confirmation).should_not be_nil
    end.should_not change(Member, :count)
  end

  it 'requires a valid email' do
    lambda do
      u = create_member(:email => nil)
      u.errors.on(:email).should_not be_nil
    end.should_not change(Member, :count)
    
    lambda do
      u = create_member(:email => 'foo')
      u.errors.on(:email).should_not be_nil
    end.should_not change(Member, :count)
    
    lambda do
      u = create_member(:email => 'foo@')
      u.errors.on(:email).should_not be_nil
    end.should_not change(Member, :count)
    
    lambda do
      u = create_member(:email => 'foo@@')
      u.errors.on(:email).should_not be_nil
    end.should_not change(Member, :count)
    
    lambda do
      u = create_member(:email => 'foo@.')
      u.errors.on(:email).should_not be_nil
    end.should_not change(Member, :count)
  end
  
  it "should determine if the user is using openid" do
    @member = members(:legacy_member)
    @member.send(:uses_openid?).should be_true
    @member.openid_profiles.delete_all
    @member.openid_profiles(true)
    @member.send(:uses_openid?).should be_false
  end
  
  it "should return nil if the member cannot be created using openid" do
    @member = members(:legacy_member)
    Member.stub!(:find_or_initialize_by_email).and_return(@member)
    @member.stub!(:save_without_validation).and_return(false)
    Member.find_or_create_by_openid_params(Member.new(:email => 'foo@bar.com')).should be_nil
    
  end

  it 'resets password' do
    m = members(:legacy_member)
    m.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    Member.authenticate(m.email, 'new password').should == m
  end
  
  it 'should generate a temporary password' do
    lambda do
      Member.reset_password()
    end.should raise_error(ArgumentError)
    
    lambda do
      Member.reset_password({})
    end.should raise_error(ArgumentError)

    lambda do
      Member.reset_password({ :email => nil })
    end.should raise_error(ArgumentError)

    lambda do
      Member.reset_password({ :email => 'bad_email@foo.com' })
    end.should raise_error(ActiveRecord::RecordNotFound)
    
    @member = members(:legacy_member)
    @old_pass = @member.crypted_password
    Member.reset_password(:email => @member.email)
    @member.reload
    @member.crypted_password.should_not == @old_pass

      # set status to suspended
    @member.status = "suspended"
    @member.save!
    lambda do
      Member.reset_password(:email => @member.email)
    end.should raise_error(Member::AccountSuspended)

      # reset status for the next test
    @member.status = "guest"
    @member.save!
    
    # Test the event that attributes cannot be updated for some reason (db failure or whatnot)
    @member.stub!(:update_attributes).and_return(false)
    Member.stub!(:find_by_email).and_return(@member)
    
    lambda do
      Member.reset_password({ :email => @member.email })
    end.should raise_error(RuntimeError)
  end

  it 'authenticates member by email' do
    Member.authenticate("legacy_member@dummydomain.com", 'test').should == members(:legacy_member)
  end
  
  it 'authenticates member by name' do
    Member.authenticate(members(:legacy_member).name, 'test').should == members(:legacy_member)
  end
  
  it 'does not authenticate deleted members' do
    Member.authenticate("deleted@dummydomain.com", 'test').should be_nil
  end

  it 'sets remember token' do
    members(:legacy_member).remember_me
    members(:legacy_member).remember_token.should_not be_nil
    members(:legacy_member).remember_token_expires_at.should_not be_nil
  end

  it 'unsets remember token' do
    members(:legacy_member).remember_me
    members(:legacy_member).remember_token.should_not be_nil
    members(:legacy_member).forget_me
    members(:legacy_member).remember_token.should be_nil
  end

  it 'remembers me for one week' do
    before = 1.week.from_now.utc
    members(:legacy_member).remember_me_for 1.week
    after = 1.week.from_now.utc
    members(:legacy_member).remember_token.should_not be_nil
    members(:legacy_member).remember_token_expires_at.should_not be_nil
    members(:legacy_member).remember_token_expires_at.between?(before, after).should be_true
  end

  it 'remembers me until one week' do
    time = 1.week.from_now.utc
    members(:legacy_member).remember_me_until time
    members(:legacy_member).remember_token.should_not be_nil
    members(:legacy_member).remember_token_expires_at.should_not be_nil
    members(:legacy_member).remember_token_expires_at.should == time
  end

  it 'remembers me default two weeks' do
    before = 10.years.from_now.utc
    members(:legacy_member).remember_me
    after = 10.years.from_now.utc
    members(:legacy_member).remember_token.should_not be_nil
    members(:legacy_member).remember_token_expires_at.should_not be_nil
    members(:legacy_member).remember_token_expires_at.between?(before, after).should be_true
  end
  
  it 'should always have a member level' do
    @new_member = Member.create(valid_member_attributes)
    @new_member.rating.should be
  end
  
  it 'should determine if it has an invite outstanding' do
    @new_member = Member.create(valid_member_attributes)
    @new_member.has_invite?.should == false
    members(:heavysixers_friend).has_invite?.should == true
  end

  describe "profile" do
    describe "when show_profile is public" do 
      before(:each) do
        @m = members(:heavysixer)
        @m.update_attributes({:show_profile => Member::Visibility::PUBLIC})
      end

      it "should be visible to guests" do
        @m.full_profile_visible_to_visitor?(nil).should be_true
      end

      it "should be visible to all nt members" do
        @m.profile_visible_to_all_nt_members?.should be_true
      end
    end

    describe "when show_profile is members" do 
      before(:each) do
        @m = members(:heavysixer)
        @m.update_attributes({:show_profile => Member::Visibility::MEMBERS})
      end

      it "should not be visible to guests" do
        @m.full_profile_visible_to_visitor?(nil).should be_false
      end

      it "should be visible to all members" do
        @m.profile_visible_to_all_nt_members?.should be_true
      end
    end

    describe "when show_profile is group" do 
      before(:each) do
        @m = members(:heavysixer)
        @m.update_attributes({:show_profile => Member::Visibility::GROUP})
      end

      it "should not be visible to guests" do
        @m.full_profile_visible_to_visitor?(nil).should be_false
      end

      it "should not be visible to all nt members" do
        @m.profile_visible_to_all_nt_members?.should be_false
      end

      it "should be visible to any nt member who is part of the same group" do
        @g = groups(:social_group)
        @m.groups << @g
        m2 = members(:heavysixers_friend)
        m2.groups << @g
        @m.full_profile_visible_to_visitor?(m2).should be_true
        m2.groups = []
        @m.full_profile_visible_to_visitor?(m2).should be_false
      end

      it "should be visible to admins" do
        @m.groups = []
        m2 = members(:heavysixers_friend)
        m2.groups = []
        @m.full_profile_visible_to_visitor?(m2).should be_false
        m2.groups << groups(:admins)
        @m.full_profile_visible_to_visitor?(m2).should be_true
      end
    end

    describe "when show_profile is private" do 
      before(:each) do
        @m = members(:heavysixer)
        @m.update_attributes({:show_profile => Member::Visibility::PRIVATE})
      end

      it "should not be visible to guests" do
        @m.full_profile_visible_to_visitor?(nil).should be_false
      end

      it "should not be visible to all nt members" do
        @m.profile_visible_to_all_nt_members?.should be_false
      end

      it "should not be visible to any nt member who is part of the same group" do
        @g = groups(:social_group)
        @m.groups << @g
        m2 = members(:heavysixers_friend)
        m2.groups << @g
        @m.full_profile_visible_to_visitor?(m2).should be_false
      end

      it "should be visible to admins" do
        @m.groups = []
        m2 = members(:heavysixers_friend)
        m2.groups = [groups(:admins)]
        @m.full_profile_visible_to_visitor?(m2).should be_true
      end
    end
  end
  
  describe "role checking" do
    it "should give permissions where they are due" do
      members(:legacy_member).has_role_or_above?("editor").should be_true
      members(:legacy_member).has_role_or_above?("admin").should be_true
      
      members(:trusted_member).has_role_or_above?("editor").should be_true
      members(:trusted_member).has_role_or_above?("admin").should be_false
      
      members(:untrustworthy_member).has_role_or_above?("editor").should be_false
      members(:untrustworthy_member).has_role_or_above?("admin").should be_false
    end
    
    it "should let member edit metadata if member level >= 3 and validation level >= 3" do
      m = members(:heavysixer)
      m.update_attribute(:validation_level, 3)
      m.has_story_edit_privileges?(stories(:legacy_story)).should be_true
    end
    
    it "should not let member edit metadata if member level >= 3 and validation level < 3" do
      m = members(:heavysixer)
      m.update_attribute(:validation_level, 2)
      m.has_story_edit_privileges?(stories(:legacy_story)).should be_false
    end
    
    it "should not let member edit metadata if member level < 3" do
      s = stories(:legacy_story)
      s.submitted_by_id=13 # because ids 1 and 2 are nt bot and nt anonymous respectively and those stories can be edited!
      s.save!
      members(:untrustworthy_member).has_story_edit_privileges?(s).should be_false
    end
    
    it "should let member edit metadata even if member level < 3 if the story is submitted by bot/guest" do
      s = stories(:legacy_story)
      s.submitted_by_id=Member.nt_bot.id
      s.save!
      members(:untrustworthy_member).has_story_edit_privileges?(s).should be_true
      s.submitted_by_id=Member.nt_anonymous.id
      s.save!
      members(:untrustworthy_member).has_story_edit_privileges?(s).should be_true
    end

    it "should let member edit metadata if he posted story, even if his member level < 3 and edit_lock is false" do
      members(:untrustworthy_member).has_story_edit_privileges?(stories(:story_5)).should be_true
    end

    it "should not let member edit metadata if he posted story if his member level < 3 and edit_lock is true" do
      members(:untrustworthy_member).has_story_edit_privileges?(stories(:contentious_story)).should be_false
    end

    it "should not let member edit metadata if his member level >=3 3 and edit_lock is true" do
      members(:heavysixer).has_story_edit_privileges?(stories(:contentious_story)).should be_false
    end

    it "should let member edit metadata if he is an editor and edit_lock is false" do
      members(:trusted_member).has_story_edit_privileges?(stories(:contentious_story)).should be_true
    end
  end

  describe "featured member list" do
    describe "on the national site" do
      it "should only list featured members" do
        Member.find(:all).each { |m| m.update_attribute(:profile_status, Member::ProfileStatus::LIST) }
        Member.find_featured.should == []
        m = Member.find(:first)
        m.update_attributes(:show_profile => Member::Visibility::PUBLIC, :show_in_member_list => true, :profile_status => Member::ProfileStatus::FEATURE)
        Member.find_featured.should == [m]
      end

      it "should only list members with public visibility" do
        Member.find(:all).each { |m| m.update_attribute(:profile_status, Member::ProfileStatus::LIST) }
        m = Member.find(:first)
        m.update_attributes(:show_profile => Member::Visibility::MEMBERS, :show_in_member_list => true, :profile_status => Member::ProfileStatus::FEATURE)
        Member.find_featured.should == []
        m.update_attributes(:show_profile => Member::Visibility::PUBLIC, :show_in_member_list => true, :profile_status => Member::ProfileStatus::FEATURE)
        Member.find_featured.should == [m]
      end

# Fab removed this requirement; Jan 28, 2011
#
#      it "should only list members who want to be listed" do
#        Member.find(:all).each { |m| m.update_attribute(:profile_status, Member::ProfileStatus::LIST) }
#        m = Member.find(:first)
#        m.update_attributes(:show_profile => Member::Visibility::PUBLIC, :show_in_member_list => false, :profile_status => Member::ProfileStatus::FEATURE)
#        Member.find_featured.should == []
#        m.update_attributes(:show_profile => Member::Visibility::PUBLIC, :show_in_member_list => true, :profile_status => Member::ProfileStatus::FEATURE)
#        Member.find_featured.should == [m]
#      end
    end

    describe "on a local site" do
      it "should only list members whose invitation code matches the invitation code of a local site" do
        ls = LocalSite.create(:name => "Environment Local Site", :slug => "environment", :subdomain => "environment", :constraint_type => "Tag", :constraint_id => 1, :is_active => true)
        i = Invitation.find(:first)
        ls.invitation_code = i.code
        ls.save!

        Member.find(:all).each { |m|
          m.update_attributes(:invitation_code => nil, :show_profile => Member::Visibility::PUBLIC, :show_in_member_list => true, :profile_status => Member::ProfileStatus::FEATURE)
        }
        Member.find_featured.map(&:id).should == Member.find(:all, :order => "members.created_at DESC").map(&:id)
        Member.find_featured(ls).should == []
        m = Member.find(:first)
        m.invitation_code = i.code
        m.save!
        Member.find_featured(ls).should == [m]
      end
    end
  end
  
protected
  def create_member(options = {})
    record = Member.new({ :login => 'quire', :email => 'quire@example.com', :name => "A Quire",
    :password => 'quire', :password_confirmation => 'quire' }.merge(options))
    record.save
    record
  end
end
