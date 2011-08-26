class Tagging < ActiveRecord::Base
  belongs_to :tag, :counter_cache => 'taggings_count'
  belongs_to :taggable, :polymorphic => true
  belongs_to :member

  def self.tagged_class(taggable)
    ActiveRecord::Base.send(:class_name_of_active_record_descendant, taggable.class).to_s
  end
  
  def self.find_taggable(tagged_class, tagged_id)
    tagged_class.constantize.find(tagged_id)
  end
  
  # for batch_autocomplete
  # note that we're sadly bypassing the acts_as_taggable way of doing things in favor of
  # the BatchUpdatableAssociations way... perhaps one day we can reconcile these.
  def name
    tag.name
  end
  def name=(name)
    self.tag = Tag.find_or_initialize_by_name(name)
  end
  
  # kinda janky... don't let member overwrite member_id if there is one.
  def member_id=(member_id)
    write_attribute(:member_id, member_id) unless self.member_id
  end

  def equals(t)
    self.tag == t.tag && self.taggable_type == t.taggable_type && self.member_id == t.member_id
  end

  def has_same_tag(t)
    self.tag == t.tag && self.taggable_type == t.taggable_type
  end
end
