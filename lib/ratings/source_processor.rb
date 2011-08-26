#
#

module Ratings
  class SourceProcessor < Processor
    # online_request: this is a request that originated from a web http request => minimal processing
    # if not, it is an offline request, and we can take all the time in the world
    def initialize(source, online_request, group)
      @source = source
      # In the general/common case, we have to compute ratings for all social groups on the site
      @groups = group ? [group] : (online_request ? [] : Group.find(:all, :conditions => {:context => Group::GroupType::SOCIAL}))
    end

    def process
      process_source_stats

      return_val = ([nil] + @groups).inject({}) { |processed_ratings_hash, g|
        g_id = g.nil? ? 0 : g.id

        # get count & average rating of 'reviewed' stories (= stories w/ a minimum of reviews) in one query
        joins = "JOIN authorships ON stories.id=authorships.story_id"
        conds = ["authorships.source_id = ? AND stories.status IN (?) AND stories.reviews_count >= ?",
                 @source.id, [Story::LIST, Story::FEATURE], SocialNewsConfig["min_reviews_for_story_rating"]]
        if !g.nil?
          joins += " JOIN group_stories ON group_stories.story_id=stories.id"
          conds[0] += " AND group_stories.group_id = ?"
          conds << g_id
        end
        reviewed_stories = Story.find(:first, :select => "count(*) AS count_all, avg(stories.rating) AS avg_rating", :joins => joins, :conditions => conds)
          # Overall site stats: more of a 'stat' than a rating per se
        @source.reviewed_stories_count = reviewed_stories.count_all if g.nil?
        group_ratings = { "overall" => reviewed_stories.avg_rating || 0.0 }

        # get average from stories for quality, popularity & each criterion
        rating_types =   Rating.criteria_keys_by_type("quality") \
                       + Rating.criteria_keys_by_type("popularity")  \
                       + ["confidence"] \
                       + SocialNewsConfig["story_rating_components"].keys 
        joins = "JOIN stories ON processed_ratings.processable_id=stories.id JOIN authorships ON stories.id=authorships.story_id"
        conds = ["authorships.source_id = ? AND stories.status IN ('list', 'feature') AND stories.reviews_count >= ? AND " +
                 "processed_ratings.rating_type IN (?) AND processed_ratings.processable_type = 'Story'",
                 @source.id, SocialNewsConfig["min_reviews_for_story_rating"], rating_types]
        if !g.nil?
          joins += " JOIN group_stories ON group_stories.story_id=stories.id"
          conds[0] += " AND group_stories.group_id = ?"
          conds << g_id
        end

        ProcessedRating.average(:value, :joins => joins, :conditions => conds, :group => 'rating_type').each do |rating_type, rating|
          group_ratings[rating_type] = rating
        end

        processed_ratings_hash[g_id] = group_ratings
        processed_ratings_hash
      }

      # SSS FIXME: This is somewhat hacky .. but not much of an option
      # Compute aggregates for this source on a per-site basis
      LocalSite.find(:all).each { |ls| 
        ss = @source.source_stats.find_by_local_site_id(ls.id)
        ss.update_stats if ss
      }

      return return_val
    end

    # as with MemberProcessor.process_member_stats, this isn't intrinsically related to
    # ratings, but now is a good time to do this...
    def process_source_stats
      @source.story_reviews_count = Review.count(
        :joins      => "JOIN authorships ON reviews.story_id=authorships.story_id",
        :conditions => {'authorships.source_id' => @source.id, 'reviews.status' => [Review::LIST, Review::FEATURE]})
    end
  end
end
