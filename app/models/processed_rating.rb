#
# ProcessedRating
#
# 'overall' computed ratings calculated by RatingProcessor (float).
#

class ProcessedRating < ActiveRecord::Base
  belongs_to :processable, :polymorphic => true
  belongs_to :group   # Can be nil which means this rating's context is the entire site
  
  validates_presence_of :value
  validates_uniqueness_of :rating_type, :scope => [:processable_id, :processable_type, :group_id]
end
