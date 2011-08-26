require 'ostruct'
class Topic < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  belongs_to :tag
  belongs_to :local_site
  has_friendly_id :slug

  attr_accessor :bypass_save_callbacks
  before_save :sluggify
  after_save  :update_tag_name, :unless => :bypass_save_callbacks

  validates_uniqueness_of :name, :scope => :local_site_id, :message => 'This name is already in use.'
  validates_uniqueness_of :slug, :scope => :local_site_id, :message => 'This slug is already in use.'

  has_one  :parent, :class_name => "Topic"
  has_many :topic_relations, :dependent => :destroy
  has_one  :image, :as => :imageable, :dependent => :destroy
  has_many :followed_items, :as => :followable, :dependent => :destroy
  has_many :followers, :through => :followed_items

  acts_as_textiled :intro
  acts_as_hostable
  has_many :subjects, :through => :topic_relations, :source => :related_topic, :conditions => "topic_relations.context ='subject'", :extend => SubjectExtension
  has_many :comments, :as => :commentable, :dependent => :destroy

  named_scope :topics_only, :conditions => { :type => nil }
  named_scope :commentable, :conditions => { :allow_comments => true }
  named_scope :with_status, lambda { |s| { :conditions => {:status => s } } }
  named_scope :for_site,    lambda { |s| { :conditions => { :local_site_id => s ? s.id : nil } } }

  define_index do
    indexes :name, :sortable => true
    indexes :type, :sortable => true
  end

  def self.site_topics(local_site=nil, find_opts={})
    Topic.for_site(local_site).topics_only.find(:all, find_opts)
  end

  def self.tagged_topic(tag, local_site=nil)
    Topic.for_site(local_site).topics_only.find(:first, :conditions => {:tag_id => tag.id})
  end

  def self.tagged_topic_or_subject(tag, local_site=nil)
    Topic.for_site(local_site).find(:first, :conditions => {:tag_id => tag.id})
  end

  def self.tagged_topics_or_subjects(tags, local_site=nil)
    Topic.for_site(local_site).find(:all, :conditions => {:tag_id => tags.map(&:id)})
  end

  def self.find_topic(slug, local_site=nil)
    Topic.for_site(local_site).find(:first, :conditions => {:slug => slug})
  end

  def name=(str)
    self[:name] = strip_tags(str)
  end
  
  def intro=(str)
    self[:intro] = strip_tags(str)
  end

  def is_public?
    self.status != "hide"
  end

  def favicon
    self.image ? self.image.public_filename(:favicon) : "/images/ui/topic_favicon.png"
  end
  
  def to_s
    name
  end

  def is_high_volume?
    topic_volume <= SocialNewsConfig["high_volume_topic_days"]
  end

  def taggings_count
    if local_site.nil?
      begin
        self.tag.taggings_count
      rescue Exception => e
        logger.error "Got exception #{e} accessing 'self.tag.taggings_count' for topic #{self.id}"
        Tag.find(self.tag_id).taggings_count
      end
    else
      Tagging.count(:joins => "JOIN taggings t2 on t2.taggable_id = taggings.taggable_id", :conditions => { "taggings.taggable_type" => "Story", "taggings.tag_id" => self.tag_id, "t2.taggable_type" => "Story", "t2.tag_id" => self.local_site.constraint_id })
    end
  end

  def subjects_to_struct
    hash = {}
    names = self.subjects.map{ |x| x.slug }
    
    # SSS FIXME: Hardcoded to use the national site subjects
    Subject.site_subjects(nil).each do | subject |
      hash[subject.slug] = names.include?(subject.slug) ? 1 : 0
    end
    
    # Add selected groupings
    hash["grouping"] = Hash[*(self.topic_relations.map{ |x| [x.related_topic.slug, x.grouping] }.flatten)]
    
    OpenStruct.new(hash)
  end

  def top_sources
    Source.top_sources_for_topic(self)
  end

  def clone_to_site(ls)
    if self.class == Topic
      nt = Topic.create(self.attributes.merge(:local_site_id => ls ? ls.id : nil))
    else
      nt = Subject.create(self.attributes.merge(:local_site_id => ls ? ls.id : nil))
    end

    self.topic_relations.each { |tr|
      TopicRelation.create(tr.attributes.merge(:local_site_id => ls ? ls.id : nil,
                                               :topic_id => Topic.tagged_topic_or_subject(tr.topic.tag, ls).id,
                                               :related_topic_id => Topic.tagged_topic_or_subject(tr.related_topic.tag, ls).id))
    }

    return nt
  end
  
  class << self
    def slug_is_subject(topic_slug)
      SiteConstants::ordered_hash("topic_subjects").keys.include?(topic_slug)
    end
    
    def get_subject_name_from_slug(topic_slug)
      SiteConstants::ordered_hash("topic_subjects")[topic_slug]["name"]
    end

    # NOTE: featured topic can be a subject, too!
    def featured_topic(local_site=nil)
      ft = LayoutSetting.find_setting(local_site, nil, "staging", "topic")
      ft ? Topic.find_topic(ft.value, local_site) : Topic.find(:first) # SSS FIXME?
    end
  end

  def sluggify
    self.slug = Slug::normalize(self.slug || self.name)
    if self.tag_id.nil? || self.tag.slug != self.slug
      t = Tag.find_or_create_by_name(self.name)
      if t.tag_type.blank?
        t.update_attributes(:tag_type => self.class.name, :slug => self.slug)
      elsif t.tag_type != self.class.name
        errors.add_to_base("You cannot create a #{self.class.name} with name #{t.name}.  There is an existing #{t.tag_type} with that name!")
        return false
      end
      self.tag = t
    end
  end

  # SSS: NOTE: In this code, all tggings with the old tag will NOT migrate over automatically
  # That is the job of the controller to provide this functionality of moving over taggings
  def update_tag_name
    t = self.tag
    new_tag = Tag.find_by_name(self.name)
    if t != new_tag
      if new_tag.nil?
        t.update_attribute(:name, self.name)
      else
        new_tag.update_attribute(:tag_type, self.class.name)
        self.bypass_save_callbacks = true
        self.update_attribute(:tag_id, new_tag.id)
        # Downgrade 't' to a regular tag if no topic/subject points to it
        t.update_attribute(:tag_type, nil) if !Topic.exists?(:tag_id => t.id)
      end
    end
  end
end
