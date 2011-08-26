class SocialGroupAttributes < ActiveRecord::Base
  belongs_to :group
  belongs_to :mynews_dummy_member, :class_name => "Member"

  after_create :create_mynews_dummy_member

  acts_as_textiled :discussion_description
  APP_NAME = SocialNewsConfig["app"]["name"]

  @@const_hash = {}

  def self.defaults
    { :num_init_story_days => 7, :category => :social, :listings => "activity" }
  end

  def self.humanize(class_name, v)
    @@const_hash["#{class_name}:#{v}"].human_name
  end

  def self.define_constants(module_ref, settings)
    module_ref.module_eval("\
      def initialize(attrs)
        @name = attrs[0]
        @human_name = attrs[1]
        @selopt_string = attrs[2]
      end

      attr_reader :name, :human_name, :selopt_string")
    const_vals = settings.collect { |s| v = module_ref.new(s); @@const_hash["#{module_ref.name.gsub(/SocialGroupAttributes::/, '')}:#{v.name}"] = v; v }
    const_vals.each { |v| module_ref.const_set(v.name.upcase, v.name) }
    module_ref.const_set("SELECT_OPTS", const_vals.collect { |v| [v.selopt_string, v.name] })
  end

  # Membership modes
  class MembershipMode
    SocialGroupAttributes.define_constants(self, [
      ["open", "Open to All", "Open to All"], 
#      ["approval", "Approval Required", "Open + Approval Required"],  # Not yet supported
#      ["email", "Email Invitation Only", "Email Invitation Only"],  # Not yet supported
      ["invitation", "Invitation-Only", "Invitation-Only"]
    ])

#    OPEN_MODES = [OPEN, APPROVAL, INVITATION]
    OPEN_MODES = [OPEN, INVITATION]
  end

  # Listing modes
  class ListingMode
    SocialGroupAttributes.define_constants(self, [
      ["members_only", "Members Only", "Only stories posted, reviewed, or starred by group members"],
      ["admin_posts", "Admin Postings Only", "Only stories posted by hosts"],
      ["all_nt", "All #{APP_NAME} Members", "All stories on #{APP_NAME}"]
    ])
  end

  # Visibility
  class Visibility
    SocialGroupAttributes.define_constants(self, [
      ["public", "Public", "Public"],
      ["nt", "Members-Only", "Only #{APP_NAME} members"],
      ["private", "Private", "Only group members"]
    ])

#    ALL = [PUBLIC, NT, PRIVATE]
  end

  # Moderation of new member reviews??
  class Moderation
    SocialGroupAttributes.define_constants(self, [
      ["staff", "Staff", "Staff Moderation"],
      ["host", "Host", "Host Moderation"],
      ["none", "No moderation", "No Moderation"]
    ])
  end

  class Category
    SocialGroupAttributes.define_constants(self, [
      ["social", "Social Group", "Social Group"],
      ["educational", "Educational Group", "Educational Group"],
      ["local", "Local Group", "Local Group"],
      ["media", "Media Group", "Media Group"],
      ["political", "Political Group", "Political Group"],
      ["professional", "Professional Group", "Professional Group"],
      ["special_interest", "Special Interest Group", "Special Interest Group"],
      ["statistical", "Statistical Group", "Statistical Group"]
    ])
  end

  AVAILABLE_LISTINGS = [
    ["Activity", "activity"], 
    ["Most Recent", "most_recent"], 
    ["Most Trusted", "most_trusted"], 
    ["Least Trusted", "least_trusted"], 
    ["New Stories", "new_stories"], 
    ["Starred", "starred"]
  ]
  # SSS: I know, I know .. view details are leaking into the model .. but want to keep all related details in one place!
  # Whenever a tab is switched, these javascript calls need to be run after the ajax call completes (see switch_tab in public/javascripts/listings.js)
  # The tabs are set up in app/helpers/groups_helper.rb
  TAB_SWITCH_CALLBACKS = {
    :most_recent   => "patch_cached_stories",
    :most_trusted  => "patch_cached_stories",
    :least_trusted => "patch_cached_stories",
    :starred       => nil,
    :new_stories   => "init_mynews",
    :activity      => "init_activity_listing"
  }
  ATLEAST_ONE_THESE_LISTINGS = AVAILABLE_LISTINGS.map(&:last)  # Useless check now that we are okay with all listings

  include Status

  STATUS_SELECT_OPTS = [HIDE, LIST, FEATURE].collect { |s| [s.capitalize, s] } 

  def create_mynews_dummy_member
    return if !self.mynews_dummy_member_id.nil?

    member_name = self.group.name
    member_name += " Group" if Member.exists?(:name => member_name)
    member_name += " Group #{Time.now.tv_usec}" if Member.exists?(:name => member_name) # Try to make the name unique
    p = Member.new_pass(8)
    m = Member.create(:name              => member_name,
                      :validation_level  => 1,
                      :email             => "#{self.group.slug}-#{SocialNewsConfig["email_addrs"]["group_base"]}",
                      :profile_status    => "hide",
                      :status            => Member::MEMBER,
                      :activated_at      => Time.now,
                      :password          => p,
                      :password_confirmation => p)
    self.update_attribute(:mynews_dummy_member_id, m.id)
  end
end
