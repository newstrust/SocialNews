class Group < ActiveRecord::Base
  class GroupType
    SOCIAL   = "social"
    ROLE     = "role"
    INTERNAL = "internal"
  end

  has_friendly_id :slug

  has_many :memberships, :as => :membershipable
  has_many :private_members, :through => :memberships, :source => :member, :conditions => ['public = ?', false]
  has_many :members, :through => :memberships, :conditions => ['public = ?', true], :extend => MembershipAssociationExtension

  # The following AR declarations are only relevant for social groups
  acts_as_hostable
  has_one  :sg_attrs, :class_name => "SocialGroupAttributes", :dependent => :delete
  has_many :invitations
  has_one  :image, :as => :imageable, :dependent => :destroy
  has_many :group_stories
  has_many :stories, :through => :group_stories
  # Discussion description is present in social group attribute
  has_many :comments, :as => :commentable, :dependent => :destroy
  named_scope :commentable, :joins => [:social_group_attributes], :conditions => { "social_group_attributes.allow_comments" => true }

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :context
  validates_presence_of :slug
  validates_uniqueness_of :slug, :message => "This slug is already in use!"

  before_save :setup_social_group_attrs
  before_destroy :verify_deletability

  attr_accessible :name, :slug, :description, :is_protected, :context

  def allow_comments?
    is_social_group? && sg_attrs.allow_comments
  end

  def discussion_description
    sg_attrs.discussion_description
  end

  def is_role?
    context == GroupType::ROLE
  end

  def is_social_group?
    context == GroupType::SOCIAL
  end

  def is_internal_group?
    context == GroupType::INTERNAL
  end

  def activated?
    sg_attrs.activated
  end

  def no_listings?
    is_social_group? && self.sg_attrs.listings.split.empty?
  end

  def listings
    self.sg_attrs.listings.split.map(&:to_sym) if is_social_group? 
  end

  def listings=(l)
    self.sg_attrs.update_attribute(:listings, l.map(&:to_s) * ' ')
  end

  def has_listing?(l)
    @curr_listings ||= self.listings
    @curr_listings.include?(l.to_sym)
  end

  def activate!
    return if !is_social_group?

    if !activated?
      sg_attrs.update_attribute("activated", "true")
      sg_attrs.update_attribute("activation_date", Time.now)
      update_group_stories(self.selected_tag_ids)
    end
  end

  def deactivate!
    return if !is_social_group?

    if activated?
       sg_attrs.update_attribute("activated", "false")
       GroupStory.delete_all(:group_id => self.id)
       ProcessedRating.delete_all(:group_id => self.id)
    end
  end

  def member_activity(last_activity_id)
    tag_ids = self.selected_tag_ids
    if tag_ids.blank?
      find_opts = {
        :joins      => "JOIN memberships ON memberships.membershipable_type='Group'" +
                                       " AND memberships.membershipable_id = #{self.id}" +
                                       " AND memberships.member_id = activity_entries.member_id",
        :conditions => last_activity_id ? ["activity_entries.id < ?", last_activity_id] : [],
        :order      => "activity_entries.id DESC", 
        :include    => {:member => [:image]},
        :limit      => SiteConstants::NUM_ACTIVITY_ENTRIES_PER_FETCH
      }
      entries = ActivityEntry.find(:all, find_opts)

      # Reject hidden entries
      ActivityEntry.reject_hidden_entries(entries)
    else
      entries = []
      entries += find_activities_by_action(last_activity_id, tag_ids, "post",    "stories.submitted_by_id")
      entries += find_activities_by_action(last_activity_id, tag_ids, "review",  "reviews.member_id")
      entries += find_activities_by_action(last_activity_id, tag_ids, "star",    "saves.member_id")
      entries += find_activities_by_action(last_activity_id, tag_ids, "comment", "comments.member_id")

      # Sort the merged list by activity id
      entries.sort! { |a, b| b.id <=> a.id }
    end

    # Reject comments on non-group objects (all comment replies are discarded for now).
    entries.reject! { |e|
      if e.activity_type == 'Comment'
        c_obj = e.activity.commentable
        (c_obj.respond_to?(:status) && c_obj.status == Status::HIDE) || \
        (c_obj.class == Story && !GroupStory.exists?(:group_id => self.id, :story_id => c_obj.id)) || \
        (c_obj.class == Review && !GroupStory.exists?(:group_id => self.id, :story_id => c_obj.story.id))
      end
    }

    # Pick the minimum number required
    return entries[0..SiteConstants::NUM_ACTIVITY_ENTRIES_PER_FETCH-1]
  end

  def members_ordered_by_activity
    Member.find(:all,
                :select  => "DISTINCT members.*",
                :joins   => "JOIN memberships ON membershipable_type='Group' AND membershipable_id=#{self.id} AND member_id=members.id" +
                            " LEFT JOIN activity_entries ON activity_entries.member_id=members.id",
                :include => [:image],
                :order   => "activity_entries.updated_at DESC")
  end

  def has_open_membership?
    SocialGroupAttributes::MembershipMode::OPEN_MODES.include?(sg_attrs.membership_mode)
  end

  def add_story(story_id)
    tags = self.selected_tag_ids
    if tags.blank? || Tagging.exists?(["taggable_id = ? AND taggable_type = 'Story' AND tag_id IN (?)", story_id, tags])
      GroupStory.find_or_create_by_story_id_and_group_id(story_id, self.id) 
    end
  end

  def process_join_request(m)
    add_member(m) if has_open_membership?
  end

  def add_member(m)
    return if has_member?(m)

    added = self.members << m
    update_group_stories(self.selected_tag_ids, m) if added && is_social_group? && activated?
    added
  end

  def has_member?(m)
    Membership.exists?(:member_id => m.id, :membershipable_type => 'Group', :membershipable_id => self.id)
  end

  def remove_member(m)
    self.members.delete(m)

    return if !activated?

    # Important: remove member first (as above) before running this query
    # Find the set of all stories that have been reviewed, starred, or posted by the member being deleted
    m_stories = GroupStory.find(:all,
       :select => "DISTINCT group_stories.*",
       :joins  => " JOIN stories ON group_stories.story_id=stories.id" +
                  " LEFT JOIN reviews ON reviews.story_id=stories.id" +
                  " LEFT JOIN saves ON saves.story_id=stories.id",
       :conditions => ["group_stories.group_id = ? AND (stories.submitted_by_id = ? OR reviews.member_id = ? OR saves.member_id = ?)", self.id, m.id, m.id, m.id])

    # Find the set of all stories that have been reviewed, starred, or posted by any other member besides the member being removed from the group
    non_exclusive_stories = GroupStory.find(:all,
       :select => "DISTINCT group_stories.*",
       :joins  => " JOIN stories ON group_stories.story_id=stories.id" +
                  " LEFT JOIN reviews ON reviews.story_id=stories.id" +
                  " LEFT JOIN saves ON saves.story_id=stories.id" +
                  " LEFT JOIN memberships m1 ON m1.member_id=reviews.member_id AND m1.membershipable_type='Group' AND m1.membershipable_id=group_stories.group_id" +
                  " LEFT JOIN memberships m2 ON m2.member_id=saves.member_id AND m2.membershipable_type='Group' AND m2.membershipable_id=group_stories.group_id" +
                  " LEFT JOIN memberships m3 ON m3.member_id=stories.submitted_by_id AND m3.membershipable_type='Group' AND m3.membershipable_id=group_stories.group_id",
       :conditions => ["group_stories.group_id = ? AND (m1.id IS NOT NULL OR m2.id IS NOT NULL OR m3.id IS NOT NULL)", self.id])

    # AR doesn't have support for deletes where joins are involved because of differing syntax between sql dbs (mysql, postgres)
    # Hence, we have to find the deletable stories first and delete them individually
    (m_stories - non_exclusive_stories).each { |gs|
      ProcessedRating.delete_all("processable_type='Story' AND processable_id=#{gs.story_id} AND group_id=#{self.id}")
      gs.destroy 
    }

    # Recompute group ratings for all stories reviewed by this member
    Review.find(:all, :conditions => ["member_id = ? && updated_at >= ?", m.id, (sg_attrs.activation_date - sg_attrs.num_init_story_days.days)]).each { |r|
      ProcessedRating.delete_all("processable_type='Review' AND processable_id=#{r.id} AND group_id=#{self.id}")
      r.story.process_in_background(self)
    }

    true
  rescue Exception => e
    logger.error "Exception #{e} removing member #{m.id} from group #{self.id}: Backtrace: #{e.backtrace.inspect}"
    false
  end

  def visible_to_member?(m)
    case sg_attrs.visibility
      when SocialGroupAttributes::Visibility::PUBLIC  then true
      when SocialGroupAttributes::Visibility::NT      then !m.nil?
      when SocialGroupAttributes::Visibility::PRIVATE then !m.nil? && (has_member?(m) || m.has_role_or_above?(:staff))
    end
  end

  def selected_tag_ids
    (sg_attrs.tag_id_list || "").split.collect { |s| s.to_i }.sort
  end

  def selected_tags
    selected_tag_ids.collect { |id| Tag.find(id) }
  end

  def find_and_delete_group_stories(find_opts)
    GroupStory.find(:all, find_opts).each { |gs|
      ProcessedRating.delete_all("processable_type='Story' AND processable_id=#{gs.story_id} AND group_id=#{self.id}")
      gs.destroy 
    }
  end

  def update_tag_selection(old_tag_ids, new_tag_ids)
    # Nothing to do if the group hasn't been activated yet
    return if !activated?

    if old_tag_ids.blank?
      # We are constraining what used to be an unconstrained group
      find_opts = {
        :conditions => ["group_id = ?" +
                        " AND NOT EXISTS (SELECT id FROM taggings WHERE taggings.tag_id IN (?)" +
                        " AND taggings.taggable_id = group_stories.story_id AND taggings.taggable_type = 'Story')",
                        self.id, new_tag_ids]
      }
      find_and_delete_group_stories(find_opts)
    elsif new_tag_ids.blank?
      # We are unconstraining what used to be an constrained group
      update_group_stories([])
    else
      # Update stories for new tags
      added_tag_ids = new_tag_ids - old_tag_ids
      if !added_tag_ids.blank?
        update_group_stories(added_tag_ids)
      end

      # Remove stories from tags that are no longer selected
      removed_tag_ids = old_tag_ids - new_tag_ids
      find_opts = {
        :conditions => ["group_id = ?" + 
                        " AND     EXISTS (SELECT id FROM taggings WHERE taggings.tag_id IN (?)" +
                                                                  " AND taggings.taggable_id = group_stories.story_id" +
                                                                  " AND taggings.taggable_type = 'Story')" +
                        " AND NOT EXISTS (SELECT id FROM taggings WHERE taggings.tag_id IN (?)" +
                                                                  " AND taggings.taggable_id = group_stories.story_id" +
                                                                  " AND taggings.taggable_type = 'Story')",
                        self.id, removed_tag_ids, new_tag_ids]
      }
      find_and_delete_group_stories(find_opts)
    end
  end

  class << self

    # A custom class method to use to bypass the restrictions inplace for attr_accessible
    # Use with care
    def create_with(opts = {})
      group = new(opts)
      group.context = opts[:context] if opts[:context]
      group.sg_attrs = SocialGroupAttributes.new(SocialGroupAttributes.defaults)
      group.save
      group
    end

    def find_by_id_or_slug(id_or_slug)
      id_or_slug.to_i.zero? ? Group.find_by_slug(id_or_slug) : Group.find(id_or_slug)
    end
  end

  private

  def setup_social_group_attrs
    # Make sure social group object is in a consistent state
    self.sg_attrs ||= SocialGroupAttributes.new(SocialGroupAttributes.defaults) if is_social_group?
    true # so, before_save always succeeds!
  end

  def verify_deletability
    errors.add_to_base('This group is protected, and cannot be deleted.') and return false if is_protected?
  end

  def constrain_find_by_action(find_opts, action, start_date)
    case action
      when "post" # nothing to do!
        nil

      when "review"
        find_opts[:select] = "DISTINCT stories.id"
        find_opts[:joins] += " INNER JOIN reviews ON reviews.story_id = stories.id"
        find_opts[:conditions][0] += " AND reviews.status IN (?) AND reviews.created_at >= ?"
        find_opts[:conditions] << [Review::LIST, Review::FEATURE]
        find_opts[:conditions] << start_date

      when "star"
        find_opts[:select] = "DISTINCT stories.id"
        find_opts[:joins] += " INNER JOIN saves ON saves.story_id = stories.id"
        find_opts[:conditions][0] += " AND saves.created_at >= ?"
        find_opts[:conditions] << start_date
    end
  end

  def constrain_find_by_actor(find_opts, actor, action_clause)
    if actor.nil?
      find_opts[:joins] += " JOIN memberships ON memberships.member_id=#{action_clause} AND " +
                                                "memberships.membershipable_type='Group' AND " +
                                                "memberships.membershipable_id=#{self.id}"
    else
      find_opts[:conditions][0] += " AND #{action_clause} = ?"
      find_opts[:conditions] << actor.id
    end
  end

  def constrain_find_by_tags(find_opts, tag_ids, base_table_clause="stories.id")
    if !tag_ids.blank?
      find_opts[:joins] += " JOIN taggings ON taggings.taggable_id=#{base_table_clause} AND taggings.taggable_type='Story'"
      find_opts[:conditions][0] += " AND taggings.tag_id IN (?)"
      find_opts[:conditions] << tag_ids
    end
  end

  def add_stories_by_action(start_date, tag_ids, action, action_clause, member = nil)
    # Base find opts -- pick listed/featured stories, after a specific date, not already present in this group
    find_opts = {
      # We need the distinct qualifier because a story might match multiple tags and thus return multiple rows for the same story
      :select     => "DISTINCT stories.id",
      :joins      => "LEFT JOIN group_stories ON group_stories.story_id = stories.id AND group_stories.group_id = #{self.id}",
      :conditions => ["stories.story_date >= ? AND stories.status IN (?) AND group_stories.id IS NULL", start_date, [Story::LIST, Story::FEATURE]]
    }

    # Pick stories based on the action and subject to it have been done on or after the start date
    constrain_find_by_action(find_opts, action, start_date)

    # Pick stories acted upon either by a specific member or by all members of the group
    constrain_find_by_actor(find_opts, member, action_clause)

    # Constrain stories to belong to a particular set of topic/subject tags
    constrain_find_by_tags(find_opts, tag_ids)

    # Find candidate stories
    new_stories = Story.find(:all, find_opts)

    # Add new stories to the group
    self.stories << new_stories

    return new_stories
  end

  def update_group_stories(tag_ids, member=nil)
    start_date = sg_attrs.activation_date - sg_attrs.num_init_story_days.days
    add_stories_by_action(start_date, tag_ids, "post", "stories.submitted_by_id", member)
    add_stories_by_action(start_date, tag_ids, "star", "saves.member_id", member)
    newly_added_reviewed_stories = add_stories_by_action(start_date, tag_ids, "review", "reviews.member_id", member)

    # Set up background processing for updating ratings!
    if member
      # Find all reviews for stories in the group when we are adding a member
      review_find_opts = { :joins => "JOIN group_stories ON group_stories.story_id=reviews.story_id AND group_stories.group_id = #{self.id}",
                           :conditions => {"reviews.member_id" => member.id} }
    else
      # Only find reviews for stories that were newly added to the group
      review_find_opts = { :joins => "", :conditions => ["story_id IN (?)", newly_added_reviewed_stories] }
      constrain_find_by_actor(review_find_opts, member, "reviews.member_id")
    end
    Review.find(:all, review_find_opts).each { |r| r.process_in_background(self) if r.is_public? }
  end

  def find_activities_by_action(last_activity_id, tag_ids, action, action_clause)
    # Base find opts -- pick activity entries that are at least older than 'last_activity_id' and order by id desc
    find_opts = {
      :joins      => "",
      :conditions => last_activity_id ? ["activity_entries.id < ?", last_activity_id] : ["true"],
      :order      => "activity_entries.id DESC",
      :include    => {:member => [:image]},
      :limit      => SiteConstants::NUM_ACTIVITY_ENTRIES_PER_FETCH
    }

    # Join with memberships table to find activities only of group members
    constrain_find_by_actor(find_opts, nil, "activity_entries.member_id")

    # Pick activities based on the action and make sure the activity object is not hidden
    case action
      when "review"
        find_opts[:joins] += " JOIN reviews ON activity_entries.activity_id=reviews.id AND activity_entries.activity_type='Review'"
        find_opts[:conditions][0] += " AND reviews.status IN (?)"
        find_opts[:conditions] << [Review::LIST, Review::FEATURE]
        action_tagging_join_clause = "reviews.story_id"

      when "post"
        find_opts[:joins] += " JOIN stories ON activity_entries.activity_id=stories.id AND activity_entries.activity_type='Story'"
        find_opts[:conditions][0] += " AND stories.status IN (?)"
        find_opts[:conditions] << [Story::LIST, Story::FEATURE]
        action_tagging_join_clause = "stories.id"

      when "star"
        find_opts[:joins] += " JOIN saves ON activity_entries.activity_id=saves.id AND activity_entries.activity_type='Save'"
        action_tagging_join_clause = "saves.story_id"

      when "comment"
        find_opts[:joins] += " JOIN comments ON activity_entries.activity_id=comments.id AND activity_entries.activity_type='Comment'"
        action_tagging_join_clause = "comments.commentable_id AND comments.commentable_type='Story'"
    end

    # Only pick activities that are specific to the group's topic/subject tags
    constrain_find_by_tags(find_opts, tag_ids, action_tagging_join_clause)

    ActivityEntry.find(:all, find_opts)
  end
end
