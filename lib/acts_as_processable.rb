#
# Processable
#
# module included by any model which has one or more 'overall' or 'processed' ratings which must be computed
# by the RatingProcessor. (note: must add method there for each type that includes Processable).
#

module ActiveRecord
  module Acts #:nodoc:
    module Processable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_processable(options = {})
          write_inheritable_attribute(:acts_as_processable_options, options)
          class_inheritable_reader :acts_as_processable_options

          has_many :processed_ratings, :as => :processable, :dependent => :destroy
          has_many :processed_rating_versions, :as => :processable, :dependent => :destroy

          # can explicity forbid processing in certain cases
          attr_accessor :dont_process

          include ActiveRecord::Acts::Processable::InstanceMethods
        end
      end

      module InstanceMethods

        # All processables should get a rating upon creation if they haven't already
        # unless dont_process is true, in which case this is probably a stub object:
        # probably an anonymous review.
        def before_create
          process(true, nil) if rating.nil? and @dont_process.nil?
        end

        # Process, save, and then process the dependents.
        #
        # online_request: this is a request that originated from a web http request => minimal processing
        # if not, it is an offline request, and we can take all the time in the world.   By default, we only
        # process sitewide ratings upfront and don't do any propagation so that reviewers (and raters)
        # get instant feedback but, we don't hold up the site doing a lot of other processing
        def save_and_process_with_propagation(online_request=true, group=nil)
          saved = save_and_process(online_request, group)
          return false if !saved

          if online_request
            Ratings::do_quick_approx_propagation(self, online_request, group)
            self.process_in_background(group)

            # SSS FIXME: This defeats the purpose of the original after_process_propagation callback
            # which to issue notifications *after* propagation.  But, we are now propagating
            # ratings in the background.
            #
            # This now also triggers a post-propagation callback which observers may implement.
            # This custom event is important because the after_save callback is too early for certain cases.
            notify(:after_processing_propagation)
          else
            propagate_processing(online_request, group) 
          end

          return true
        end

        # queue record in table to be picked up by bj
        # n.b. processing is implicitly propagated!
        def process_in_background(group = nil)
          group_id = group.nil? ? nil : group.id
          if !ProcessJob.exists?(:processable_id => self.id, :processable_type => self.class.name, :group_id => group_id)
            ProcessJob.create(:processable => self, :group_id => group_id) 
          end
        end

        def processed_rating(rating_type, group=nil)
          group_id = (group.nil? ? nil : group.id)
          # Even though this looks inefficient in the presence of 10s of ratings, all processed ratings will be accessed during rating calculations.
          # So, it is efficient to fetch everything in one shot from the db, rather than fetch each one separately
          pr = processed_ratings.detect {|pr| pr.rating_type==rating_type && pr.group_id==group_id }
          return pr.value if pr
        end

        def last_processed_rating_value
          prv = ProcessedRatingVersion.find(:last, :conditions => { :processable_id => self.id, :processable_type => self.class.name})
          prv ? prv.value : 0.0
        end

        # imitate new_record logic in ActiveRecord::Base so that our custom callback after
        # propagation can still know whether this is a create or an update.
        def was_new_record?
          defined?(@was_new_record) && @was_new_record
        end

        # Method to fetch a group-specific rating
        def group_rating(group, rating_type="overall")
          group_id = group.nil? ? nil : group.id
          if group_id.nil? && rating_type == "overall"
            self.rating
          else
            pr = ProcessedRating.find(:first, :select => "value", :conditions => {:processable_id => self.id, :processable_type => self.class.name, :group_id => group_id, :rating_type => rating_type})
            pr.value if pr
          end
        end

        private

          # Process before saving -- no one should be able to call this directly!
          def save_and_process(online_request, group)
            @was_new_record = new_record?
            return process(online_request, group) && save(false)
          end

          def propagate_processing(online_request, group)
            # By default, everything is done in the background, if this is an online request
            safe_to_array(dependent_processables).each { |p|
              if online_request || acts_as_processable_options[:background]
                p.process_in_background(group)
              else
                p.save_and_process_with_propagation(false, group)
              end
            }
          end

          # Process -- no one should be able to call this directly!
          def process(online_request, group)
            new_ratings = Ratings::process(self, online_request, group)

            # Sort keys so that group_id 0 is always processed first if it exists
            # Otherwise, in some cases, the story rating might not be initialized which
            # will break 'compute_sort_rating' for a group -- it will return nil
            new_ratings.keys.sort.each { |group_id|
              group_ratings = new_ratings[group_id]

              # Special code for sitewide ratings (record versions for sitewide overallr atings
              if (group_id == 0)
                # save OVERALL rating directly into the model (removing it from array)
                self.rating = group_ratings.delete("overall")

                # save historic rating value, too (if non-nil... reviews alone may have nil ratings)
                # TODO: we probably _should_ save a version even if it's a new record...
                # Don't bother with saving a version if the difference is marginal!
                # Actually, this is a good thing because of rounding errors anyway
                if self.rating && !new_record? && ((self.rating - last_processed_rating_value).abs > 0.001)
                  ProcessedRatingVersion.create(:rating_type => "overall", :value => self.rating, :processable => self)
                end

                # Reset sitewide group id to nil
                group_id = nil
              end

              # Dump the ratings into the db
              grs = group_ratings.collect { |k, rating| ProcessedRating.new(:rating_type=>k, :value=>rating, :group_id => group_id) if rating }.compact

              # Remove old processed ratings for this group
              ProcessedRating.delete_all(:group_id => group_id, :processable_type => self.class.name, :processable_id => self.id)

              # Append (do not assign!) new processed ratings -- because we might have re-computed processed ratings only for
              # a subset of all groups that this object belongs to.  Assignment deletes all of them.
              self.processed_ratings << grs.flatten

              # update cached group rating values for stories
              if group_id && (self.class == Story)
                r  = group_ratings["overall"]
                rc = group_ratings["reviews_count"]
                sr = compute_sort_rating(group_id == 0 ? nil : Group.find(group_id))
                GroupStory.update_all("rating = #{r}, sort_rating = #{sr}, reviews_count = #{rc}", "group_id = #{group_id} AND story_id = #{self.id}")
              end
            }

            return true # so that 'save_' methods return result of save, not of this
          end

          # was thinking of imitating ActiveRecord::Validations::evaluate_condition
          # so models could pass in symbols instead of procs, but ehh...
          def dependent_processables
            if acts_as_processable_options[:dependents]
              acts_as_processable_options[:dependents].call(self)
            end
          end

          # based on version in ActiveRecord::Base
          def safe_to_array(o)
            case o
              when Array: o
              when NilClass: []
              else [o]
            end.flatten # wtf why is it wrapping arrays in arrays?!
          end

      end
    end
  end
end
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Processable)
