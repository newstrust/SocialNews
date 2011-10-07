class Comment < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  APP_NAME = SocialNewsConfig["app"]["name"]

  can_be_flagged :reasons => [ :like, :flag ]
  acts_as_nested_set
  has_many :replies, :class_name => 'Comment', :foreign_key => :parent_id do
    def as_hash
      @owner.for_json.merge({
        :replies_count => visible.count,
        :replies => map do |r|
          { :title => r.title,
            :id => r.id,
            :body => r.body,
            :created_at => r.created_at.strftime("%m/%d/%Y %I:%M %p"),
            :member => r.member.for_json,
            :replies_count => r.replies.count,
            :replies => r.replies.as_hash
          }
        end
      })
    end
  end

  belongs_to :member
  acts_as_textiled :body
  validates_presence_of :member_id
  validates_member_can_comment
  @@body_character_limit = 2000
  cattr_reader :body_character_limit
  @@minutes_before_locked = 30
  cattr_reader :minutes_before_locked
  validates_length_of :body_plain, :maximum => @@body_character_limit, :message => "Responses must be #{@@body_character_limit} characters or less."
  attr_protected :replies, :member

  after_flagged :after_flagged_notifications

  # Attribute for the parent_id, we can't call it parent_id becase acts_as_nested_set protects that attribute.
  attr_accessor :initial_ancestor_id
  named_scope :visible, :conditions => { :hidden => false, :hidden_through_muzzle => false }
  named_scope :sources, :conditions => { :commentable_type => 'Source' }
  named_scope :top, :conditions => ["parent_id IS NULL", false]

  def can_be_edited_by?(m = nil)
    !m.nil? && editable? && self.member.id == m.id
  end

  def can_be_hidden_by?(m = nil)
    !m.nil? && m.has_role_or_above?(:editor)
  end

  def visible?
    !hidden? && member.can_comment?
  end

  def likes(force = false)
    unless force
      @likes ||= flags.find(:all, :conditions => { :reason => 'like' }, :include => :member )
    else
      @likes = flags.find(:all, :conditions => { :reason => 'like' }, :include => :member )
    end
    @likes
  end

  def likes_count(force = false)
    unless force
      @likes_count ||= flags.count(:all, :conditions => { :reason => 'like' })
    else
      @likes_count = flags.count(:all, :conditions => { :reason => 'like' })
    end
    @likes_count
  end

  def flags_count(force = false)
    unless force
      @flags_count ||= flags.count(:all, :conditions => { :reason => 'flag' })
    else
      @flgs_count = flags.count(:all, :conditions => { :reason => 'flag' })
    end
    @flags_count
  end

  def for_json
    {
      :likes_count => likes_count,
      :flags_count => flags_count,
      :parent_id => parent.nil? ? nil : parent.id,
      :id => id,
      :body => body,
      :created_at => created_at.strftime("%m/%d/%Y %I:%M %p"),
      :member => member.for_json,
      :replies_count => replies.count
    }
  end

  def all_visible_children
    c = all_children.reject{|x| x.hidden || x.hidden_through_muzzle }
  end

  def editable_time_left
    Comment.minutes_before_locked - ((Time.now - updated_at) / 60).floor
  end
  def editable?
    editable_time_left > 0
  end

  def title=(str)
    self[:title] = strip_tags(str)
  end

  def body=(str)
    self[:body] = strip_tags(str)
  end

  def nest_inside(p_id)
    if p_id
      @parent = Comment.find(p_id)
      move_to_child_of(@parent)
    end
  end

  def commentable
    commentable_type.constantize.send(:find, commentable_id) if commentable_type
  rescue NameError
    nil
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # commentable_types using Topic could be something else because of STI.
  # To be sure we have the right type we need to retrieve the Topic record itself to get the 
  # type.
  def commentable_type
    read_attribute(:commentable_type) == 'Topic' ? Topic.find(commentable_id).class.to_s : read_attribute(:commentable_type)
  end

  # The can_flag plugin is rather opinionated and expects a user model not a member model so we
  # work around it thusly
  def user_id
    member.id
  end

  def notification_list
    list = { 
      :replies => [], 
      :likes =>[], 
      :recipients => [SocialNewsConfig["comments_alert_recipient"]].flatten
    }

    if parent
      # Anyone who has also replied to the parent comment of the new comment
      list[:replies] = siblings.map{|x| x.member }.reject{|x| !x.email_notification_preferences.replied_comment_replied_to || x.id == member_id }.uniq

      # Anyone who likes the parent of this comment.
      list[:likes] = parent.likes.map{ |x| x.member }.reject{ |x| !x.email_notification_preferences.liked_comment_replied_to || x.id == member_id }.uniq
    end
    list[:recipients] += commentable.hosts.map(&:email) if (commentable && commentable.respond_to?(:hosts))

    return list
  end

  def deliver_notifications
    nl = notification_list

    # notify staff of the new comment
    Mailer.deliver_comment_posted({ 
      :recipients => nl[:recipients],
      :subject => "New #{commentable_type.downcase} comment on #{APP_NAME}",
      :body => { :comment => self }
    })

    # notify reviewer of a new comment on their review, but not if they made the comment themselves
    if commentable_type == 'Review'
      review = commentable
      if review.member.email_notification_preferences.review_commented_on && member != review.member
        NotificationMailer.deliver_review_comment({
          :recipients => review.member.email,
          :subject => "#{member.display_name} commented on your review on #{APP_NAME}",
          :body => { :review => review, :record => self, :to => review.member}
        })
      end
    end

    if parent

      # Notify the parent member that someone replied to their comment.
      if parent.member.email_notification_preferences.comment_replied_to && parent.member.id != member_id
        NotificationMailer.deliver_comment_replied_to({
          :recipients => parent.member.email,
          :subject => "#{member.display_name} replied to your comment on #{APP_NAME}",
          :body => { :record => self, :to => parent.member}
        }) unless member.id == parent.member.id
      end

      # Notify anyone who has also replied to the parent comment of the new comment
      nl[:replies].each do |replier|
        NotificationMailer.deliver_comment_replied_to({
          :recipients => replier.email,
          :subject => "#{member.display_name} also replied to a comment by #{parent.member.display_name} on #{APP_NAME}",
          :body => { :record => self, :to => replier }
        })
      end

      # Notify members who likes the parent comment.
      nl[:likes].each do |liker|
        NotificationMailer.deliver_liked_comment_replied_to({
          :recipients => liker.email,
          :subject => "#{member.display_name} replied to a comment you like on #{APP_NAME}",
          :body => { :record => self, :to => liker }
        }) unless nl[:replies].include?(liker)
      end
    end
  end

  def validate_on_create
    if commentable_type && commentable_id
      record = commentable_type.capitalize.constantize.find(commentable_id)
      errors.add(:commentable_type, "does not allow comments") unless record.allow_comments?
    end
  end

  def after_create
    member.increment!(:total_meta_comments)
    ActivityScore.boost_score(Story.find(commentable_id), :comment, {:member => member, :obj => self}) if (commentable_type == 'Story')
    ActivityEntry.create(:member_id => member.id, :activity_type => 'Comment', :activity_id => self.id)
  end

  def after_destroy
    member.decrement!(:total_meta_comments)
    flags.destroy_all
  end

  # NOTE: Because of the way RAILS does STI stuff if you save the commentable_type as 
  # anything other than TAG for any class that inherits from Topic it won't find the record
  # in the record.comments proxy association. To get around this I am resetting the commentable_type
  # to Topic right before i save it.
  def before_create
    self.commentable_type = 'Topic' if !self.commentable_type.blank? && self.commentable_type.capitalize.constantize.superclass == Topic
  end

  def after_flagged_notifications
    flag = flags(true).last
    return unless flag.reason
    case flag.reason
    when "like"
      if member.email_notification_preferences.comment_liked
        NotificationMailer.send("deliver_like_content_notice", { 
          :recipients => member.email,
          :subject => "#{flag.member.display_name} likes your comment on #{APP_NAME}",
          :body => { :record => self }})
      end
    else
      NotificationMailer.send("deliver_#{flag.reason}_content_notice", { 
        :recipients => notification_list[:recipients],
        :subject => "[#{APP_NAME.upcase} FLAGGED CONTENT]",
        :body => { :record => self }})
    end
  end
end
