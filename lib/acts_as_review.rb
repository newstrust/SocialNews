#
# Review
#
# module included by any model which has one or more 'overall' or 'processed' ratings which must be computed
# by the RatingProcessor. (note: must add method there for each type that includes Review).
#

module ActiveRecord
  module Acts #:nodoc:
    module Review #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_review(options = {})
          belongs_to :member
          has_many :ratings, :as => :ratable, :dependent => :destroy

          include ActiveRecord::Acts::Review::InstanceMethods
        end
      end
      
      module InstanceMethods
        def component_rating(criterion)
          rating = ratings.select{ |r| r.criterion==criterion }.first
          return rating.value if rating
        end

        # overwrite this as reviews from legacy will have no member_rating (as they are processed before members...!)
        # Fall back on 0.0 if review is not attached to a member yet (i.e., it's a guest review)
        def member_rating(group=nil)
          (self.member ? self.member.group_rating(group, "overall") : 0.0) || 0.0
        end
        
        # just blow away all existing ratings every time for now
        def rating_attributes=(ratings_attributes)
          self.ratings = ratings_attributes.collect do |key, rating_attributes|
            Rating.new(rating_attributes) if !rating_attributes["value"].blank?
          end.compact
        end
        
      end
    end
  end
end
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Review)
