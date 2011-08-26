module Ratings
  class ReviewProcessor < Processor
    # specific group:
    #   if a group is passed in, we compute rating only for the group requested
    #
    # online_request:
    #   this is a request that originated from a web http request => minimal processing
    #   we only compute ratings sitewide
    #
    # if not, it is a background rating computation request, and we can take all the time in the world
    #   we compute ratings not just sitewide but for all the social groups that the reviewer belongs to
    #
    def initialize(review, online_request, group)
      @review = review
      # In the general/common case, we have to compute ratings for all social groups that the reviewer belongs to
      @groups = group ? [group] : [nil] + (online_request ? [] : (@review.member ? @review.member.social_groups : []))
    end

    # Temporary story rating value after the first review so that the zero rating trustometer
    # doesn't show up for newly reviewed stories
    def do_quick_approx_propagation
      story = @review.story
      if story.reviews_count < 2
        story.rating = @review.rating
        story.save(false)
      end
    end

    def process
      @processed_ratings = {}
      @groups.each { |g|
        if g.nil?
          @processed_ratings[0] = process_review_overall  # sitewide ratings
        else
          @processed_ratings[g.id] = process_review_overall  # sitewide ratings; FIXME: Duplicate computation? but faster than loading from db?
        end
        process_review_meta(g)
        process_review_confidence(g) if @review.member # don't bother with this if it's the temp object from ReviewsController.overall_rating
      }
      return @processed_ratings
    end

    def process_review_overall
      processed_ratings = {}
      weight_value_pairs = []
      SocialNewsConfig["story_rating_components"].each do |key, component|
        value = send("review_" + key)
        if !value.nil?
          weight_value_pairs.push({:value => value, :weight => component["weight"]})
          processed_ratings[key] = value
        end
      end
      processed_ratings["overall"] = Ratings::do_weighted_average(weight_value_pairs)

      return processed_ratings
    end

    def review_quality
      weight_value_pairs = []
      type_category = @review.story.type_category
      @review.ratings.each do |r|
        criterion = Rating.criterion(r.criterion, "quality")
        if criterion
          weight_value_pairs.push({
            :value => r.value,
            :weight => criterion["weight"][type_category]})
        end
      end
      return Ratings::do_weighted_average(weight_value_pairs)
    end

    def review_popularity
      weight_value_pairs = []
      Rating.each_criterion_by_type("popularity") do |key, criterion, form_level|
        value = case key
        when "recommendation"
          @review.component_rating("recommendation")
        when "trust"
          # SSS: Source trust is not used in computing overall rating if the form version is mini!
          @review.source_review.rating if @review.form_version != "mini" && @review.source_review
        end
        weight_value_pairs.push({:value => value, :weight => criterion["weight"] }) if value
      end
      return Ratings::do_weighted_average(weight_value_pairs)
    end

    # do meta total (of meta_reviews of this review)
    # DF points out that weighting here measures meta-reviewers' member levels on 
    # a relative scale, not an absolute one. see Ratings::do_weighted_average().
    def process_review_meta(group)
      meta_reviews = @review.meta_reviews_from_group(group)
      if !meta_reviews.empty?
        weight_value_pairs = []
        meta_reviews.each do |mr|
          meta_reviewer_rating = mr.member_rating(group) || 1 # default to 1 for site recalc (chicken & egg scenario)
          weight_value_pairs.push({
            :value => mr.rating,
            :weight => meta_reviewer_rating ** SocialNewsConfig["member_level_weight_exponent"]})
        end
        group_id = group.nil? ? 0 : group.id
        @processed_ratings[group_id]["meta"] = Ratings::do_weighted_average(weight_value_pairs)
      end
    end

    # Rating confidence is how much we believe in the caliber of this review. It is a float between 0.0-1.0.
    # It's used for the second-order weighting in StoryProcessor.
    # Only the exponential "member_rating" is not 1-5; we just scale everything down anyway.
    def process_review_confidence(group)
      group_id = group.nil? ? 0 : group.id
      weight_value_pairs = []
      SocialNewsConfig["review_weighting_component_weights"].each do |component, weight|
        value = case component
        when "member_rating"
          @review.member_rating(group) ** SocialNewsConfig["member_level_weight_exponent"]
        when "quality_ratings_completeness"
          (@review.ratings.length / Rating.criteria_keys_by_type("quality").length * 5).constrain(1..5)
        when "monitoring_rating"
          @review.component_rating("knowledge")
        when "meta_review_rating"
          @processed_ratings[group_id]["meta"]
        end
        weight_value_pairs.push({:value => value, :weight => weight }) if !value.nil?
      end
       unscaled_confidence = Ratings::do_weighted_average(weight_value_pairs)
       @processed_ratings[group_id]["confidence"] = unscaled_confidence / Ratings::ReviewProcessor.max_confidence_rating
    end

    class << self
      # We need to know the maximum possible confidence rating so that we can lower the bar in process_review_confidence.
      # Only do this calculation the very first time; then just pull it out of a class variable. Love this Ruby syntax.
      def max_confidence_rating
        @@max_confidence_rating ||= begin
          weight_value_pairs = []
          SocialNewsConfig["review_weighting_component_weights"].each do |component, weight|
            value = 5 ** (component == "member_rating" ? SocialNewsConfig["member_level_weight_exponent"] : 1)
            weight_value_pairs.push({:value => value, :weight => weight })
          end
          Ratings::do_weighted_average(weight_value_pairs) # at the time of writing, this will return 17
        end
      end
    end

  end
end
