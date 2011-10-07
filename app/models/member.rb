# Member

require 'digest/md5'

class Member < ActiveRecord::Base
  acts_as_processable
  acts_as_tagger
  can_flag

  MEMBER     = "member"
  GUEST      = "guest"
  TERMINATED = "terminated"
  SUSPENDED  = "suspended"
  DUPLICATE  = "duplicate"

  INACTIVE_STATUS_CHOICES = [SUSPENDED, TERMINATED]
  @@hide_status_choices = [GUEST, DUPLICATE] + INACTIVE_STATUS_CHOICES 
  @@status_choices = @@hide_status_choices + [MEMBER]
  cattr_reader :status_choices, :hide_status_choices

  class AccountSuspended < StandardError
  end

  module ProfileStatus
    LIST    = "list"
    FEATURE = "feature"
    HIDE    = "hide"
    VISIBLE = [LIST, FEATURE]
    ALL     = VISIBLE + [HIDE]
  end

  # SSS: FIXME: Any changes here should also be reflected in config/social_news_constants/member_constants.yml
  module Visibility
    PUBLIC  = "public"
    MEMBERS = "members"
    GROUP   = "group"
    PRIVATE = "private" # activated only for students
  end

  # SSS: FIXME: Any changes here should also be reflected in config/social_news_constants/member_constants.yml
  module EducationalStatus
    NONE           = "none"
    HIGH_SCHOOL    = "high_school"
    UNIVERSITY     = "university"
    HS_EDUCATOR    = "high_school_educator"
    UNIV_EDUCATOR  = "university_educator"
    STUDENT  = [HIGH_SCHOOL, UNIVERSITY]
    EDUCATOR = [HS_EDUCATOR, UNIV_EDUCATOR]
    ALL = [NONE] + STUDENT + EDUCATOR
  end
  
  @@profile_flex_fields = [
    "about", "age_group", "affiliations", "company", "job_title", "expertise", "educational_status",
    "favorite_links", "gender", "home_page", "income", "interests", "languages", "politics",
    "street_address", "street_address2", "city", "state", "zip_code", "country", "phone",
  ]
  @@other_flex_fields = [
    # invitation things
    "invitation_code", "invitation_date", "invites", "total_invited",
    # legacy-ish things?
    "how_heard_about_us", "last_visit", "edit_notes", "email_address_history",
    # review form things
    "review_form_expanded",
    # survey tracking code
    "survey_code",
    # awards
    "awards"
  ]
  @@tracking_flex_fields = [
    "http_user_agent", "http_x_real_ip"
  ]

  MYNEWS_STATS_FIELDS = ["mynews_last_visit_at", "mynews_num_visits", "mynews_last_guest_visit_at", "mynews_num_guest_visits"]

  cattr_reader :profile_flex_fields, :other_flex_fields, :tracking_flex_fields

  has_friendly_id :name, :use_slug => true

  has_many :reviews, :order => 'created_at DESC'
  has_many :meta_reviews
  has_eav_behavior :fields => @@profile_flex_fields + @@other_flex_fields + @@tracking_flex_fields + MynewsListing::MYNEWS_DEFAULT_SETTINGS.keys + MYNEWS_STATS_FIELDS

  # Required for Openid Support
  has_many :openid_profiles, :dependent => :destroy
  has_many :comments
  has_many :memberships, :dependent => :destroy
  has_many :groups, :through => :memberships, :source =>:membershipable, :source_type => 'Group'
  has_many :member_donations
  belongs_to :referring_member, :foreign_key => :referred_by, :class_name => 'Member'
  belongs_to :edited_by_member, :class_name => "Member"
  belongs_to :validated_by_member, :class_name => "Member"
  has_many :saves, :class_name => "Save"
  has_one :image, :as => :imageable, :dependent => :destroy
  has_many :source_affiliations, :class_name => "Affiliation", :extend => BatchAssociationExtension
  has_many :affiliated_sources, :through => :source_affiliations, :source => :source
  has_many :favorites, :extend => BatchAssociationExtension
  has_many :favorite_tags, :through => :favorites, :source => :tag, :conditions => "favorites.favoritable_type = 'Tag'"
  has_many :newsletters, :through => :newsletter_recipients
  has_many :sharables
  has_one  :facebook_connect_settings
  has_one  :twitter_settings
  has_many :facebook_invitations
  has_many :fb_shared_reviews, :through => :sharables, :source => :review, :conditions => "sharables.sharable_type = 'Review' AND sharables.sharable_target = '#{Sharable::FACEBOOK}'"
  has_many :page_hosts

  # my followers associations
  has_many :follower_items, :class_name => "FollowedItem", :as => :followable
  has_many :followers, :through => :follower_items

  # my followed items associations
  has_many :followed_items, :foreign_key => "follower_id"
  has_many :followed_topics,  :through => :followed_items, :source => :topic,  :conditions => "followed_items.followable_type = 'Topic'"
  has_many :followed_members, :through => :followed_items, :source => :member, :conditions => "followed_items.followable_type = 'Member'"
  has_many :followed_feeds,   :through => :followed_items, :source => :feed,   :conditions => "followed_items.followable_type = 'Feed'"
  has_many :followed_sources, :through => :followed_items, :source => :source, :conditions => "followed_items.followable_type = 'Source'"

  # activity entries: post, review, comment, save/star/like
  has_many :activity_entries

  # social network friendship info (cached info)
  has_many :social_network_friendships

  # is subscribed to many (can be zero) newsletters
  has_many :newsletter_subscriptions

  acts_as_textiled :about

  attr_accessor :identity_url
  before_create :make_activation_code
  after_create :make_openid_profile

    # If the member status is being changed from list -> hide or hide -> list,
    # we have to update the reviews count (decrement / increment) because reviews
    # from hidden members don't count
  attr_accessor :bypass_save_callbacks
  before_save :record_member_status, :unless => :bypass_save_callbacks
  before_save :encrypt_password, :unless => :bypass_save_callbacks
  before_save :update_member_stats, :unless => :bypass_save_callbacks
  after_save  :update_review_counts_if_necessary, :unless => :bypass_save_callbacks
  after_save  :process_fb_tw_settings, :unless => :bypass_save_callbacks

    # Strip leading/trailing spaces from fields
  before_validation :strip_blanks
  
    # Enter the list of any staff members whose names shouldn't show up in the posting credits list.
    # Important: This has to be after declaration of friendly-id
  ACTIVE_STAFF_IDS = [].collect { |s| begin; m = Member.find(s); rescue; end; m.id if m }.compact

  # Thinking Sphinx Search Configurations
  define_index do
    # fields 
    indexes :name, :sortable => true
    indexes :email, :sortable => true
    indexes member_attributes.name, :as => :member_attributes_name
    indexes member_attributes.value,:as => :member_attributes_value
    
    # These attribute are used for narrowing the search results.
    has status
    has show_profile
    has updated_at, :as => :sort_field
  end

  # Virtual attribute for the unencrypted password
  attr_accessor :password
 
  # Virtual attribute for the partner invitation in the instances when the user was created
  # with the help of a partner. We need to store this info because the member_observer
  # needs access to get custom message text.
  attr_accessor :invitation

  validates_presence_of     :name
  validates_uniqueness_of   :name, :case_sensitive => false
  validates_presence_of     :email
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  # validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_uniqueness_of :email, :case_sensitive => false
  validates_format_of     :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_inclusion_of  :status, :in => @@status_choices, :message => "This is not an available choice.", :allow_nil => true
  validates_acceptance_of :terms_of_service

  # Store email_notification_preferences in a serialized Preferences object.
  # See also virtual accessors below.
  # DF: removed :review_meta_reviewed from keys below
  class Preferences
    @@keys = [:comment_liked, :comment_replied_to, :liked_comment_replied_to, :replied_comment_replied_to, :story_edited, :submitted_story_reviewed, :reviewed_story_reviewed, :liked_story_reviewed, :followed_member, :review_commented_on]
    @@keys.each{|key| attr_accessor key}
    def initialize
      @@keys.each{|attr| self.send("#{attr}=", true)} # assume they're all bools for now
    end
  end
  serialize :email_notification_preferences # don't specify Preferences class here... makes serialize barf on legacy data

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  # attr_accessible :name, :email, :password, :password_confirmation # :login
  # AF: trying to whitelist rather than blacklist here, because of sheer number of flex attributes.
  # we might be able to recycled the above list, tho. tbd.
  # DF: I removed :status from the list below to make it editable by staff on the profile form
  attr_protected :muzzled, :comments, :groups, :member_donations, :memberships, :meta_reviews, :openid_profiles, :reviews, :saves, :pseudonym

  named_scope :active, :conditions => ["status NOT IN (?)", INACTIVE_STATUS_CHOICES]

  def self.find_by_slug(slug)
    Member.find(:first, :joins => "JOIN slugs on members.id = slugs.sluggable_id and slugs.sluggable_type='Member'", :conditions => ["slugs.name = ?", slug])
  end

  def first_name
    self.display_name.split(" ").first
  end

  # Maybe this should be refactored into using a has_many :through style association?
  # For now it doesn't matter because we need groups anyway for other things.
  def roles
    groups.find(:all, :conditions => {:context => Group::GroupType::ROLE})
  end

  def social_groups
    groups.find(:all, :conditions => {:context => Group::GroupType::SOCIAL})
  end

  def hostings(local_site=nil)
    self.page_hosts.reject { |ph| ph.local_site != local_site }.map(&:hosting)
  end

  def hosted_topics(local_site=nil)
    self.page_hosts.reject { |ph| ph.local_site != local_site || ph.hosting.hostable_type != "Topic" }.map(&:hosting).map(&:hostable)
  end

  def hosted_sources(local_site=nil)
    self.page_hosts.reject { |ph| ph.local_site != local_site || ph.hosting.hostable_type != "Source" }.map(&:hosting).map(&:hostable)
  end

  def hosted_groups(local_site=nil)
    self.page_hosts.reject { |ph| ph.local_site != local_site || ph.hosting.hostable_type != "Group" }.map(&:hosting).map(&:hostable)
  end

  # Likes this member has given
  def likes(force = false)
    if force || @likes.nil?
      @likes = flags.all(:conditions => { :reason => 'like' })
    end
    @likes
  end

  # Likes this member has given
  def likes_count(force = false)
    if force || @likes_count.nil?
      @likes_count = flags.count(:conditions => { :reason => 'like' })
    end
    @likes_count
  end

  # Flags the member has given
  def flags_count(force = false)
    if force || @flags_count.nil?
      @flags_count = flags.count(:conditions => { :reason => 'flag' })
    end
    @flags_count
  end

  # Flags this member has received.
  def flaggings_count(force = false)
    if force || @flaggings_count.nil?
      @flaggings_count = flaggings.count(:conditions => { :reason => 'flag' })
    end
    @flaggings_count
  end

  # Likes this member has received
  def likings(force = false)
    if force || @likings.nil?
      @likings = flaggings.all(:conditions => { :reason => 'like' })
    end
    @likings
  end
  # Likes this member has given
  def likings_count(force = false)
    if force || @likings_count.nil?
      @likings_count = flaggings.count(:conditions => { :reason => 'like' })
    end
    @likings_count
  end

  def has_specific_role?(role)
    roles.map(&:slug).include?(role.to_s)
  end

  def has_role?(role)
    has_role_or_above?(role)
  end

  def has_role_or_above?(role)
    role_index = Role.all_slugs.index(role.to_s)
    return false if role_index.nil?

    required_roles = Role.all_slugs[0, role_index+1]
    return !(roles.map(&:slug) & required_roles).empty?
  end

  def has_host_privilege?(hostable, override_role, local_site=nil)
    self.has_role_or_above?(override_role) || (hostable && hostable.hosts(local_site).include?(self))
  end

  def in_group?(group_slug)
    groups.map(&:slug).include?(group_slug.to_s)
  end

  def belongs_to_group?(group)
    group && groups.to_ary.find { |g| g.id == group.id }
  end

  # Don't let ppl edit story metadata if someone who outranks them already has!
  # And if no one of note has edited the story, let them through.
  # (Alternate algorithm: just check if member is trusted. But this seems more fair.)
  # Changed so unless the story has been locked it's now open to any trusted member, or members who posted the story or for stories that were submitted by the bot or by a guest submitter
  # DF - 7/31/09
  def has_story_edit_privileges?(story)
    has_role_or_above?(:host) || (!story.edit_lock && (is_trusted_member? || [self, Member.nt_bot, Member.nt_anonymous].include?(story.submitted_by_member)))
  end

  def has_invite?
    (activation_code && referring_member) ? true : false
  end

  def fb_uid
    facebook_connect_settings ? facebook_connect_settings.fb_uid : nil
  end

  # This is for a new member
  def fbc_link(fb_session)
    fb_uid = fb_session["user_id"]
    access_token = fb_session["access_token"]
    if self.new_record?
      self.facebook_connect_settings = FacebookConnectSettings.new(:fb_uid => fb_uid, :offline_session_key => access_token, :access_token => access_token)
    elsif facebook_connect_settings.nil?
      FacebookConnectSettings.create(:member_id => self.id, :fb_uid => fb_uid, :offline_session_key => access_token, :access_token => access_token)
      self.reload  # so that the newly created facebook_connect_settings attribute is visible
    else
      facebook_connect_settings.update_attributes(:fb_uid => fb_uid, :offline_session_key => access_token, :access_token => access_token)
    end
  end

  def fbc_unlink
    # Remove the user's Facebook newsfeed from the user's follows!
    ff = fbc_newsfeed
    if !ff.nil?
      fi = FollowedItem.find(:first, :conditions => {:followable_id => ff.id, :followable_type => 'Feed', :follower_id => self.id})
      fi.destroy if fi
    end

    # Remove facebook social network friendships
    SocialNetworkFriendship.clear_friendships(SocialNetworkFriendship::FACEBOOK, self.id)

    if facebook_connect_settings
      facebook_connect_settings.update_attributes(:fb_uid => nil, :access_token => nil, :ep_offline_access => 0, :ep_read_stream => 0, :friendships_cached => false)
    end
  end

  def fb_app_friends(access_token)
    app_friend_fb_ids = facebook_connect_settings.rest_api_call(access_token, "friends.getAppUsers") || []
    Member.find(:all, :joins => :facebook_connect_settings, :conditions => ["facebook_connect_settings.fb_uid IN (?)", app_friend_fb_ids.map(&:to_s)])
  end

  def fbc_linked?
    !fb_uid.nil?
  end

  def fbc_autofollow_friends?
    facebook_connect_settings ? facebook_connect_settings.autofollow_friends : nil
  end

  def fbc_autofollow_friends=(v)
    facebook_connect_settings.update_attribute(:autofollow_friends, v) if facebook_connect_settings
  end

  def fbc_newsfeed
    Feed.find(:first, :conditions => {:member_profile_id => self.id, :feed_type => Feed::FB_UserStream})
  end

  def fbc_followable_friends(fb_session)
    return [] if !facebook_connect_settings
    cache_facebook_friendship_info(fb_session) if !facebook_connect_settings.friendships_cached
    SocialNetworkFriendship.facebook_friends(self.id)
  end

  def fbc_friends_with?(m2, fb_session)
    return false if !fbc_linked? || !m2.fbc_linked? 
    cache_facebook_friendship_info(fb_session) if !facebook_connect_settings.friendships_cached
    SocialNetworkFriendship.are_friends?(SocialNetworkFriendship::FACEBOOK, self, m2)
  end

  def follows_fb_newsfeed?
    f = fbc_newsfeed
    f && FollowedItem.exists?(:follower_id => self.id, :followable_type => 'Feed', :followable_id => f.id)
  end

  def can_follow_fb_newsfeed?
    fbc_linked? && facebook_connect_settings.ep_read_stream && facebook_connect_settings.ep_offline_access
  end

  def follow_member(m)
    FollowedItem.add_follow(self.id, 'Member', m.id)
  end

  def mutual_follower?(m)
    m && FollowedItem.mutual_followers?(self, m)
  end

  def twitter_connected?
    twitter_settings && twitter_settings.tw_uid 
  end

  def twitter_link(access_token)
    # Record/update the access token info.
    ts = twitter_settings
    if ts.nil?
      ts = TwitterSettings.create(:member_id => self.id, :access_token => access_token.token, :secret_token => access_token.secret)
      self.reload
    else
      ts.update_attributes({:access_token => access_token.token, :secret_token => access_token.secret})
    end

    # Get user info from twitter and record it -- for now, we will only use the twitter id
    user_client = ts.authed_twitter_client
    user_info = user_client.verify_credentials
    ts.update_attributes({:tw_id => user_info["id"], :tw_uid => user_info["screen_name"]})

    # Cache twitter friendship info
    cache_twitter_friendship_info
  end

  def twitter_unlink
    # Remove the user's Twitter newsfeed from the user's follows!
    tf = twitter_newsfeed
    if tf
      fi = FollowedItem.find(:first, :conditions => {:followable_id => tf.id, :followable_type => 'Feed', :follower_id => self.id})
      fi.destroy if fi
    end

    # Remove twitter social network friendships
    SocialNetworkFriendship.clear_friendships(SocialNetworkFriendship::TWITTER, self.id)

    if twitter_settings
      twitter_settings.update_attributes({:tw_id => nil, :tw_uid => nil, :access_token => nil, :secret_token => nil, :friendships_cached => false})
    end
  end

  # Pass-thru convenience method
  def authed_twitter_client
    twitter_settings.authed_twitter_client if twitter_settings
  end

  def twitter_follower?(m2)
    return false if !twitter_connected? || !m2.twitter_connected? 
    cache_twitter_friendship_info if !twitter_settings.friendships_cached
    SocialNetworkFriendship.are_friends?(SocialNetworkFriendship::TWITTER, self, m2)
  end

  def twitter_followable_friends
    return [] if !twitter_settings
    cache_twitter_friendship_info if !twitter_settings.friendships_cached
    SocialNetworkFriendship.twitter_friends(self.id)
  end

  def twitter_newsfeed
    Feed.find(:first, :conditions => {:member_profile_id => self.id, :feed_type => Feed::TW_UserNewsFeed})
  end

  def follows_twitter_newsfeed?
    f = twitter_newsfeed
    f && FollowedItem.exists?(:follower_id => self.id, :followable_type => 'Feed', :followable_id => f.id)
  end

  def is_trusted_member?
       ((self.rating || 0) >= SocialNewsConfig["min_trusted_member_level"].to_f) \
    && ((self.validation_level || 0) >= SocialNewsConfig["min_trusted_member_validation_level"].to_i)
  end

  def can_comment?
    !([nil] + @@hide_status_choices).include?(status) && !muzzled? && validation_level >= SocialNewsConfig["min_validation_level_for_comments"]
  end

  def can_post?
#    !([nil] + @@hide_status_choices).include?(status) && rating && (rating >= SocialNewsConfig["min_member_rating_for_posts"])
    !([nil] + @@hide_status_choices).include?(status) && validation_level >= SocialNewsConfig["min_validation_level_for_posts"]
  end

  def not_muzzled
    !muzzled
  end

  def enforce_student_constraints!
    if !is_student?
      self.show_profile = Visibility::GROUP if self.show_profile == Visibility::PRIVATE # Cannot be private if not a student!
    elsif self.educational_status == EducationalStatus::HIGH_SCHOOL
      self.show_profile = Visibility::PRIVATE
      self.show_email = false
      self.show_in_member_list = false
    end
  end

  def record_request_env(reqenv)
    @@tracking_flex_fields.each { |f| self.send("#{f}=", reqenv[f.upcase]) }
  end

  def favicon
    self.image ? self.image.public_filename(:favicon): "/images/ui/silhouette_favicon.jpg"
  end

  def small_thumb
    self.image ? self.image.public_filename(:small_thumb): "/images/ui/silhouette_tiny.jpg"
  end

  def process_guest_actions(submits, reviews, source_reviews)
    dupes = {}
    (submits || []).each { |s_id|
      begin
        s = Story.find(s_id)
          # Some other member might have submitted the same story since -- so, check that the submitter is still anonymous
        if s.submitted_by_id == Member.nt_anonymous.id
          s.submitted_by_id = self.id
          s.save_and_process_with_propagation 
          ActivityScore.boost_score(s, :member_submit, {:member => self})
        end
      rescue Exception => e
        logger.error "Exception #{e} processing guest story submission #{s_id}; #{e.backtrace.inspect}"
      end
    }

    (reviews || []).each { |r_id| 
      begin
        r = Review.find(r_id) 
        orig_r = Review.find(:first, :conditions => {:story_id => r.story_id, :member_id => self.id})
        if orig_r.nil?
          r.member_id = self.id 
          r.status = Review::LIST
          r.save_and_process_with_propagation 
          ActivityEntry.update_all("member_id = #{self.id}", {:activity_type => 'Review', :activity_id => r.id})
        else
          sid = orig_r.story.id
          dupes[sid] ||= []
          dupes[sid] << orig_r
          dupes[sid] << r
        end
      rescue Exception => e
        logger.error "Exception #{e} processing guest review #{r_id}; #{e.backtrace.inspect}"
      end
    }

    (source_reviews || []).each { |r_id| 
      begin
        r = SourceReview.find(r_id)
        orig_r = SourceReview.find(:first, :conditions => {:source_id => r.source_id, :member_id => self.id})
        if orig_r.nil?
          r.member_id = self.id
          r.status = Review::LIST
          r.save_and_process_with_propagation
        else
            # For source reviews, we always keep the original!
          r.destroy
        end
      rescue Exception => e
        logger.error "Exception #{e} processing guest review #{r_id}; #{e.backtrace.inspect}"
      end
    }

      # Get rid of duplicates and sort so that the review with the smallest id is considered the original review
    dupes.values.each { |v| v.uniq!; v.sort! { |r1, r2| r1.id <=> r2.id } }

      # This is the array of dupe reviews of the form: [ [r1, r2, r3], [r10, r11], [r14, r15] ]
    return dupes.values
  end

  def publish_reviews_and_posts
    # and publish all stories/reviews
    Review.update_all("status = '#{Review::LIST}'", :member_id => self.id, :status => Review::HIDE)
    Story.update_all("status = '#{Story::LIST}'", :submitted_by_id => self.id, :status => Story::HIDE)
  end

  def story_review(story)
    Review.find(:first, :conditions => {:story_id => story.id, :member_id => self.id})
  end

  def has_published_review?(review_id, target)
    r = Sharable.find(:first, :conditions => {:member_id => self.id, :sharable_type => "Review", :sharable_id => review_id, :sharable_target => target}) if !review_id.nil?
    return !r.nil?
  end

  def record_published_review(review_id, target)
    if !has_published_review?(review_id, target)
      self.sharables << Sharable.new(:sharable_type => 'Review', :sharable_id => review_id, :sharable_target => target) 
    end
  end

  def shared_reviews_count(target)
    Sharable.count(:conditions => {:member_id => self.id, :sharable_type => 'Review', :sharable_target => target})
  end
  
  # This invitation would be supplied by the partner not another user.
  def accept_invitation(invite)
    self.invitation= invite
    self.validation_level = invite.validation_level
    self.invitation_code = invite.code
  end

  def activate_without_save
    @activated = true
    self.activated_at = Time.now.utc
    self.activation_code = nil
    self.status = MEMBER

    # and publish all stories/reviews
    publish_reviews_and_posts
  end

  # Activates the user in the database.
  def activate
    activate_without_save
    save(false)
      # Process any member level calculations as required -- updates total_reviews count
    process(true, nil)
  end

  def active?
    # the existence of an activation code means they have not activated yet
    # activation_code.nil?
    self.status != GUEST
  end
  
  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password) #, salt)
  end
  
  def authenticated?(password)
    crypted_password == encrypt(password)
  end
  
  # 'remember me' stuff... not using this yet.
  #
  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end
  
  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 10.years
  end
  
  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end
  
  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end
  
  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end
  
  # Pseudonym code is in a half-baked state... t.b.d.
  def display_name
    name # !pseudonym.blank? ? pseudonym : name
  end

  def has_newsletter_subscription?(nl_type)
    NewsletterSubscription.exists?(:member_id => self.id, :newsletter_type => nl_type)
  end

  def add_newsletter_subscription(nl_type)
    self.newsletter_subscriptions << NewsletterSubscription.create(:newsletter_type => nl_type) if !has_newsletter_subscription?(nl_type)
  end

  def remove_newsletter_subscription(nl_type)
    NewsletterSubscription.delete_all(:member_id => self.id, :newsletter_type => nl_type) if has_newsletter_subscription?(nl_type)
  end

  def update_newsletter_subscription(nl_type, flag)
    if (flag == true) || (flag == "true")
      add_newsletter_subscription(nl_type)
    elsif (flag == false) || (flag == "false")
      remove_newsletter_subscription(nl_type)
    end
  end

  def mynews_newsletter
    has_newsletter_subscription?(Newsletter::MYNEWS)
  end

  def mynews_newsletter=(flag)
    update_newsletter_subscription(Newsletter::MYNEWS, flag)
  end

  # SSS: attrs are a set of checkboxed values for different newsletter frequencies
  # So, if a newsletter type is present, the member is subscribed to it.  If it is absent, the member is unsubscribed from it.
  # FIXME: Maybe imitate Rails hidden field hack to always get something passed in?
  def newsletter_subscription_attrs=(attrs)
    subscribed = attrs ? attrs.keys : []
    subscribed.each { |s| add_newsletter_subscription(s) }
    (Newsletter::VALID_NEWSLETTER_TYPES - subscribed).each { |s| remove_newsletter_subscription(s) }
  end

    ## Generate a newsletter unsubscribe key for sending out with the newsletter
    ## FIXME: In the future, the key should encode the newsletter id!
  def newsletter_unsubscribe_key(newsletter)
    h = name.hash
    h = -h if h < 0
    return "#{id*47}:#{'%x' % h}"
  end

  # ------------------------------------------------------------------------------------------------------
  # show_profile, profile_status, status is_public?, is_visible?, is_public_profile?, has_visible_profile?
  # Argh!! ... what are all these?
  #
  # show_profile        -- controlled by member (public, members, group)
  # status              -- controlled by editors (member, guest, suspended, terminated, duplicate) -- consolidate!
  # profile_status      -- controlled by editors (hide, student, list, feature)
  # is_public?          -- member.status is not hidden
  # is_visible?         -- is_public?  && profile.status is not hidden
  # has_public_profile? -- is_visible? && show_profile is set to 'public'
  # profile_visible_to_all_nt_members -- exactly what it says
  # full_profile_visible_to_visitor?(m) -- exactly what it says
  # ------------------------------------------------------------------------------------------------------

  # note that this function determines if the member's reviews are processed,
  # so don't check profile_status or show_profile here...
  def is_public?
    !@@hide_status_choices.include?(self.status)
  end

  # ...rather, do it here
  # note: no longer checking 'show_profile' here. if set to 'members', that only should block
  # non-members from seeing the profile page
  def is_visible?
    is_public? && ProfileStatus::VISIBLE.include?(profile_status)
  end

  # SSS: Why 3 different methods?
  def terminated?
    INACTIVE_STATUS_CHOICES.include?(self.status)
  end

  def is_student?
    EducationalStatus::STUDENT.include?(self.educational_status)
  end

  def is_educator?
    EducationalStatus::EDUCATOR.include?(self.educational_status)
  end

  # can use this to determine if RSS should be public. Means anyone can view their profile page if true
  def has_public_profile?
    is_visible? && (show_profile == Visibility::PUBLIC)
  end

  def profile_visible_to_all_nt_members?
    is_visible? && [Visibility::PUBLIC,Visibility::MEMBERS].include?(show_profile)
  end

  def shares_group_membership_with?(m)
    !(self.groups & m.groups).empty?
  end

  # checks viewing member status as well as target member's profile settings to see if target member's profile is visible.
  # don't use this for their RSS feed.
  def full_profile_visible_to_visitor?(m, opts={:override_role => :staff})
    opts[:newsletter] ||= false
    if opts[:newsletter]    # no use for 'm' in this case .. we assume m is nil (i.e. check for public visibility)
      has_public_profile?
    else
         # - 'm' is the profile owner
         # - 'm' has the required override role (editor, host, admin, etc.)
         # - 'm' is visible && either the profile is public or m is not nil & profile is visible to members or m is not nil & m shares groups membership
         (m == self) \
      || (!m.nil? && m.has_role_or_above?(opts[:override_role])) \
      || (is_visible? && (   (show_profile == Visibility::PUBLIC) \
                          || (!m.nil? && (show_profile == Visibility::MEMBERS)) \
                          || (!m.nil? && (show_profile == Visibility::GROUP) && m.shares_group_membership_with?(self))))
    end
  end
  
  # copy the 'edited by' fields into the 'validated by' ones if there was a change
  # virtual 'force_update_validator' field lets you force that.
  def validation_level=(new_validation_level)
    write_attribute(:validation_level, new_validation_level)
    update_validator_from_editor if validation_level_changed?
  end
  def force_update_validator=(force_update_validator)
    update_validator_from_editor unless force_update_validator.to_i.zero?
  end
  def force_update_validator
    false
  end
  
  # any time the email address is changed, make sure to save a copy of the 
  # old one in member.email_address_history 
  def email=(new_email)
    email_history_array = eval(self.email_address_history || "")
    email_history_array ||= []
    email_history_array << new_email unless email_history_array.include?(new_email)
    self.email_address_history = email_history_array.inspect
    write_attribute(:email, new_email)
  end
  
  # virtual accessors for email_notification_preferences. Marshal type to Preferences before serialize does its thing.
  def email_notification_preferences=(prefs_attributes)
    prefs = self.email_notification_preferences # init the object if it wasn't there
    prefs_attributes.each{|key, val| prefs.send("#{key}=", val=="true")}
    write_attribute(:email_notification_preferences, prefs)
  end
  def email_notification_preferences
    enp_attr = read_attribute(:email_notification_preferences)
    new_attributes = Preferences.new.instance_variables - enp_attr.instance_variables
    if new_attributes.empty?
      enp_attr
    else
      prefs = Preferences.new
      # New preferences were added, which this user didnt have so we need to add them to the mix.
      enp_attr.instance_variables.map { |x| prefs.instance_variable_set(x, enp_attr.instance_variable_get(x)) }
      prefs
    end
  end
  
  # for batch_autocomplete
  def source_affiliations_attributes=(source_affiliations_attributes)
    source_affiliations.attributes_collection = source_affiliations_attributes
  end
  def favorites_attributes=(favorites_attributes)
    favorites.attributes_collection = favorites_attributes
  end

  def average_rating_by_member(member)
    MetaReview.average(:rating, :joins => "JOIN reviews ON meta_reviews.review_id=reviews.id",
      :conditions => {'meta_reviews.member_id' => member.id, 'reviews.member_id' => self.id}) if member
  end

  def for_json
    {
      :id => id,
      :display_name => display_name
    }
  end

  class<<self
    def nt_bot; Member.find(1); end
    def nt_anonymous; Member.find(2); end
    def nt_tagger; Member.find(3); end

    def find_recent_reviewers(how_many, opts = {})
      opts[:with_photo] ||= false
      opts[:is_logged_in] ||= false
      opts[:home_page_name_list] ||= false
      opts[:local_site] ||= nil

      # For performance reasons (too many table joins -- 5 when on a local site), fetch member_ids from the review table 
      # and then pick the right members in the ruby loop below.  Hence, we are setting up two different condition strings

      conditions_reviews = "reviews.member_id IS NOT NULL"   # Because we have 'guest' reviews from way back when!
      conditions_members = "members.status = '#{MEMBER}'"    # Should have member status

      # Hidden profiles cannot be shown for non-logged in members
      conditions_members += " AND members.show_profile = '#{Visibility::PUBLIC}'" if !opts[:is_logged_in]

      # Left join images table to check for presence/absence of an image
      join_str = "LEFT JOIN images ON images.imageable_type='Member' AND images.imageable_id=reviews.member_id"
      if opts[:with_photo]
        #  If photo requested, only fetch members with photo
        conditions_reviews += " AND images.id IS NOT NULL"

        # ---- Temporarily disabled ----
        # # only show photos if member level >= 2
        # conditions_members += " AND members.rating >= 2"
      else
        # If no photo flag set, then we want those without photos
        conditions_reviews += " AND images.id IS NULL"

        # ---- Temporarily disabled ----
        # # If home page flag set, we want only those with a member rating >= 2
        # conditions_members += " AND members.rating >= 2" if opts[:home_page_name_list]
      end

      local_site = opts[:local_site]
      if local_site
        join_str += " JOIN stories on reviews.story_id = stories.id"
        join_str += " JOIN taggings on stories.id = taggings.taggable_id AND taggings.taggable_type = 'Story'"
        conditions_reviews += " AND taggings.tag_id = #{local_site.constraint.id}"
      end

      results         = []
      member_id_hash  = {}
      fetched_members = []
      no_excludes_yet = true
      count           = opts[:with_photo] ? 4*how_many : 2*how_many

      num_attempts = 0
      while (num_attempts < 20) do
        num_attempts += 1

          # Fetch member ids of reviews -- wont necessarily be unique -- it is okay, faster to deal with it in Ruby
        candidate_reviews = Review.find(:all,
                                        :from       => "reviews USE INDEX (index_reviews_on_created_at_and_member_id)",
                                        :joins      => join_str,
                                        :conditions => conditions_reviews,
                                        :order      => "reviews.created_at DESC",
                                        :select     => "reviews.member_id",
                                        :limit      => count)

          # No hope getting any more
        break if candidate_reviews.empty?

          # Fetch members who meet the cut 
        reviewers = Member.find(:all, :conditions => conditions_members + " AND id in (#{candidate_reviews.map(&:member_id) * ","})")

          # No hope getting any more
        break if reviewers.empty?

          # Add reviewers to a hash because the order from the member query is not the right order -- we'll use the reviews array to get the order right
        mems = {}
        reviewers.each { |m| mems[m.id] = m }

        candidate_reviews.each { |r|
          m_id = r.member_id
          m = mems[m_id]

            # The reviewer didn't make the cut!
          next if m.nil? 

            # We already have this member! 
          next if member_id_hash[m_id]

            # Add m to the result set
          results << m
          member_id_hash[m_id] = true
          break if results.size == how_many
        }

          # Are we done?
        break if (results.size == how_many)

          # No!  Go back and fetch more members!
        fetched_members = member_id_hash.keys

          # Update conditions!
        column_to_exclude = "reviews.member_id"
        if no_excludes_yet
          conditions_reviews += " AND #{column_to_exclude} NOT IN (#{fetched_members * ','})"
          no_excludes_yet = false
        else
          conditions_reviews.gsub!(/#{column_to_exclude} NOT IN \(.*?\)/, "#{column_to_exclude} NOT IN (#{fetched_members * ','})")
        end
      end

      return results
    end

      ## Verify a provided newsletter unsubscribe key and fetch the member who is unsubscribing!
      ## FIXME: In the future, the key should encode the newsletter id!
    def get_unsubscribing_member(key)
      key_parts = key.split(':')
      begin
        member_id = key_parts[0].to_i/47
        m = Member.find(member_id)
        h = m.name.hash
        name_hash = "%x" % ((h >= 0) ? h : -h)
        return (key_parts[1] == name_hash) ? m : nil
      rescue Exception => e
        logger.error "Bad unsubscribe key: #{k}; Caught exception: #{e}"
        return nil
      end
    end
    
    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    # NOTE: WebX let users log in by name also. Let's stop allowing that, because those needn't be unique.
    def authenticate(name_or_email, password)
      m = active.find_by_email(name_or_email)
      m = active.find_by_name(name_or_email) unless m 
      m && m.authenticated?(password) ? m : nil
    end

    def reset_password(params)
      raise ArgumentError unless params[:email]
      m = find_by_email(params[:email])
      raise ActiveRecord::RecordNotFound unless m
      raise AccountSuspended if m.terminated?
      pass = new_pass(8)
        # Set the password_reset field so that on sign in, we can redirect the user to the member account page to reset their password
      m.update_attributes(:password => pass, :password_confirmation => pass, :password_reset => true) ? pass : raise(RuntimeError)
    end

    # Encrypts password withOUT a salt. (just like WebX used to do; MD5, too.)
    def encrypt(password) #, salt)
      Digest::MD5.hexdigest(password)
    end

    def find_by_identity_url(openid_url)
      openid_profile = OpenidProfile.find_by_openid_url(openid_url, :include => :member)
      openid_profile.nil? ? nil : openid_profile.member
    end

    def create_through_member_referral(referring_member, email)
      @member = find_or_initialize_by_email(:email => email)
        ## SSS: Set a dummy name based on email so that the friendly id generator doesn't generate slugs called 'unknown-1' ... etc
        ## which will soon hit the limit of max-allowed similar friendly ids (right now, 10)
      @member.name = email.gsub(/@/, '_').gsub(/\./, '_')
      raise(ArgumentError, "Invalid Email") unless email =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
      raise(ActiveRecord::StatementInvalid, "Member Exists") unless @member.new_record?
      @member.validation_level = referring_member.rating
      @member.referred_by = referring_member.id
      if @member.save_without_validation
        @member
      else
        nil
      end
    end
        
    def find_or_create_by_openid_params(record)
      return nil if record.email.blank?
      member = find_or_initialize_by_email(:email => record.email)
      
      %w(login email name identity_url).each do | v |
        member.send("#{v}=", record.send("#{v}")) unless record.send("#{v}").blank?
      end
      
      # The Member model has numerous validations that a virgin openid account won't pass.
      if member.save_without_validation
        member
      else
        nil
      end
    end
    
    # for member listing
    def find_featured(local_site = nil)
      lsic = local_site.invitation_code if local_site && local_site.invitation_code
      ms = find(:all,
           :joins      => lsic ? "JOIN member_attributes ON member_attributes.member_id=members.id AND member_attributes.name='invitation_code' AND member_attributes.value like '%#{lsic}%'" : "",
           :include    => :image,
           :conditions => {:profile_status      => ProfileStatus::FEATURE,
                           # Jan 28, 2011: Fab requested that this field be ignored
                           # :show_in_member_list => true,
                           :show_profile        => "#{Visibility::PUBLIC}"},
           :order      => "members.created_at DESC")

      # No need to reject false hits.  We want substring match 
      # Ex: ABC-PUBLIC, ABC-NYT, ABC-SCHOOL
      #
      # # reject false hits
      # ms.reject! { |m| !(m.invitation_code || "").split(",").map(&:strip).include?(lsic) } if lsic
      return ms
    end

    # for mynews popup
    def find_trusted
       find(:all,
            :joins => :reviews,
            :include => :image,
            :group => "members.name",
            :conditions => ["members.rating >= ? AND reviews.created_at >= ? AND profile_status IN (?) AND show_in_member_list = true", SocialNewsConfig["min_trusted_member_level"].to_f, Time.now - 180.days, ProfileStatus::VISIBLE], 
            :order => "members.name")
    end
    
    # def search(query, scope = {}, conditions = {})
    #   unless scope.empty?
    #     with_scope(:find => scope) { search_using(query, conditions) }
    #   else
    #     search_using(query, conditions)
    #   end
    # end

    def new_pass(len)
      chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      newpass = ""
      1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
      return newpass
    end
    
    protected
    
    def search_using(query, conditions = {})
      paginate_options = { :per_page => 10, :page => 1 }.merge(conditions)
      # http://en.wikipedia.org/wiki/Stop_words
      # http://www.dcs.gla.ac.uk/idom/ir_resources/linguistic_utils/stop_words
      stopwords = %w(a an the of I it you and in on or)

      words = query.split(/\s+/) - stopwords
      
      raise StandardError if words.empty?
      
      sql_where = ''
      
      words.each do |word|
        # Escape single quotes
        word.gsub!("'", "\\\\'")
      
        ['login', 'email', 'name'].each do |c|
          sql_where += "#{c} LIKE '%#{word}%' OR "
        end
      end
      
      sql_where = sql_where[0..-5] # Strip last 5 characters
      
      paginate({ :conditions => sql_where }.merge(paginate_options))
    end


  end

  def make_activation_code
    self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end  

  def update_review_stats
    if !self.id.nil?
      self.total_reviews = Review.visible.count(:conditions => {:member_id => self.id})
      self.total_answers = Rating.count(
        :joins => " JOIN reviews ON ratings.ratable_id=reviews.id AND reviews.status in ('list', 'feature')" +
                  " JOIN stories ON stories.id=reviews.story_id AND stories.status in ('list', 'feature')",
        :conditions => {'reviews.member_id' => self.id, 'ratings.ratable_type' => Review.name})
    end
  end

  def update_metareview_stats
    if !self.id.nil?
      self.total_meta_reviews_given = MetaReview.visible.count(:conditions => {:member_id => self.id})
      self.total_meta_reviews_received = MetaReview.visible.count(:conditions => {'reviews.member_id' => self.id})
      self.total_meta_reviewers = MetaReview.visible.count(:conditions => {'reviews.member_id' => self.id},
        :select => "DISTINCT meta_reviews.member_id")
    end
  end

  def cache_facebook_friendship_info(fb_session)
    return if fb_session.nil?

    friends_on_nt = fb_app_friends(fb_session["access_token"])
    SocialNetworkFriendship.add_friendships(SocialNetworkFriendship::FACEBOOK, self, friends_on_nt)
    facebook_connect_settings.update_attribute(:friendships_cached, true)
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Error caching Facebook friendship info for #{self.id}; Exception is #{e}; Backtrace: #{e.backtrace.inspect}"
  end

  protected
  
  def make_openid_profile
    self.openid_profiles.create(:openid_url => identity_url) unless identity_url.blank?
  end
  
  def uses_openid?
    !openid_profiles.empty?
  end
  
  # before filter.
  def encrypt_password
    return if password.blank?
    # self.salt = Digest::MD5.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end
    
  def password_required?
    crypted_password.blank? || !password.blank?
  end
  
  def update_validator_from_editor
    if last_edited_at_changed?
      self.validated_by_member_id = edited_by_member_id
      self.last_validated_at = last_edited_at
    end
  end

  def strip_blanks
    [self.email, self.name, self.pseudonym, self.activation_code].compact.each(&:strip!)
  end

  private

  def record_member_status
      # This load will come from the cache (the per-request cache that rails maintains)
    m = self.id ? Member.find(self.id) : nil
    @is_public_before_save = m ? Member.find(self.id).is_public? : is_public?
    return true
  end

  def update_review_counts_if_necessary
    is_public_after_save = is_public?
    update_story_reviews_count(is_public_after_save ? 1 : -1) if (is_public_after_save != @is_public_before_save)
  end

  def process_fb_tw_settings
    # Unlink from FB and Twitter when a member is terminated
    if self.status_changed? && self.terminated?
      self.facebook_connect_settings = nil
      self.twitter_settings = nil
    end
  end

  def update_story_reviews_count(update_value)
      # Custom SQL code for updating reviews_count value for all stories that have been reviewed by this member
    Member.connection.update("UPDATE stories, reviews SET stories.reviews_count = stories.reviews_count + #{update_value} WHERE reviews.member_id = #{self.id} and stories.id = reviews.story_id AND reviews.status != '#{Review::HIDE}' AND (reviews.disclosure IS NULL OR reviews.disclosure NOT IN (#{SiteConstants::ordered_hash("review_disclosure").select{|k, v| v["exclude_rating"]}.collect {|x| '"'+x[0]+'"'} * ','}))")

      # Alternative ruby-based code for the above sql code.  This ruby code is inefficient for members with lot of reviews.
    # self.reviews.each { |r| Story.update_reviews_count(r.story_id, update_value) if !r.hidden? && r.include_rating?)}

      # Queue for background processing all public stories which had a non-hidden review by this member
    self.reviews.each { |r| r.story.process_in_background if (!r.hidden? && r.include_rating? && r.story.is_public?) }
  end

  def update_member_stats
    update_review_stats
    update_metareview_stats
  end

  def cache_twitter_friendship_info
    ts = twitter_settings
    tw_ids = ts.twitter_friend_ids
    if tw_ids.is_a? Array
      friends_on_nt = Member.find(:all, :joins => :twitter_settings, :conditions => ["twitter_settings.tw_id IN (?)", tw_ids.map(&:to_s)])
      SocialNetworkFriendship.add_friendships(SocialNetworkFriendship::TWITTER, self, friends_on_nt)
    end
    tw_ids = ts.twitter_follower_ids
    if tw_ids.is_a? Array
      followers_on_nt = Member.find(:all, :joins => :twitter_settings, :conditions => ["twitter_settings.tw_id IN (?)", tw_ids.map(&:to_s)])
      SocialNetworkFriendship.add_followers(SocialNetworkFriendship::TWITTER, self, followers_on_nt)
    end
    ts.update_attribute(:friendships_cached, true)
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Error caching Twitter friendship info for #{self.id}; Exception is #{e}; Backtrace: #{e.backtrace.inspect}"
  end
end
