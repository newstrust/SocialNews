class SourceReview < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :source
  belongs_to :member

  acts_as_processable
  acts_as_review

  named_scope :for_site,   lambda { |s| { :conditions => { :local_site_id => s ? s.id : nil } } }
  named_scope :for_member, lambda { |m| { :conditions => { :member_id => m.id } } }

  include Status
  
  belongs_to :source
  
  validates_presence_of :source_id
  validates_presence_of :member_id
  validates_uniqueness_of :source_id, :scope => [:local_site_id, :member_id]
  
  # HACK. virtual getter for ajax overall_rating call, as a temp source review won't have a rating yet.
  def rating
    read_attribute(:rating) || component_rating("trust")
  end

  def expertise_topics
    (expertise_topic_ids || "").split(",").collect { |s| s.to_i }.sort.collect { |id| Topic.find(id) }
  end

  def incomplete?
    rating.nil? || (note.blank? && expertise_topic_ids.blank?)
  end
end
