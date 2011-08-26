class Save < ActiveRecord::Base
  belongs_to :member
  belongs_to :story, :counter_cache => 'saves_count'
  
  validates_uniqueness_of :member_id, :scope => [:story_id]
end
