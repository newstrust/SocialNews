module Ratings
  class StoryProcessor < Processor
    # Use this middle-of-the-road confidence value as we may NOT do a full recalc after all.
    DEFAULT_CONFIDENCE = 0.5

    # specific group:
    #   if a group is passed in, we compute rating only for the group requested
    #
    # online_request:
    #   this is a request that originated from a web http request => minimal processing
    #   we only compute ratings sitewide
    #
    # if not, it is a background rating computation request, and we can take all the time in the world
    #   we compute ratings not just sitewide but for all the social groups that the story belongs to
    #
    def initialize(story, online_request, group)
      @story = story
      # In the general / common case, we have to compute ratings for all social groups that the story belongs to
      @groups = group ? [group] : [nil] + (online_request ? [] : story.groups)
    end

    def process
      @processed_ratings = {}
      @groups.each { |g|
        @processed_ratings[g.nil? ? 0 : g.id] = {}
        add_group_reviews_count(g) if !g.nil?
        process_story_reviews(g) # must explicitly do reviews first as popularity depends on "recommendation" avg
        process_story_popularity(g)
        process_story_overall(g)
        process_story_individual_criteria(g)
      }
      return @processed_ratings
    end

    def add_group_reviews_count(group)
      return if group.nil?
      @processed_ratings[group.id]["reviews_count"] = @story.public_reviews_for_ratings.inject(0) { |n, r| n + (r.member.belongs_to_group?(group) ? 1 : 0) }
    end

    # assumes "quality" & "popularity" are already set in @processed_ratings
    def process_story_overall(group)
      g_id = group.nil? ? 0 : group.id
      weight_value_pairs = []
      SocialNewsConfig["story_rating_components"].each do |key, component|
        value = @processed_ratings[g_id][key]
        weight_value_pairs.push({:value => value, :weight => component["weight"]}) if value
      end
      @processed_ratings[g_id]["overall"] = Ratings::do_weighted_average(weight_value_pairs)
    end

    # get the quality, popularity (i.e., "recommendation") & source recommendation (i.e. "trust") ratings avgs.
    # 'review_popularity' gets mixed in with auto criteria to create FULL popularity in process_story_popularity below
    def process_story_reviews(group)
      process_story_review_component(group, "quality") do |review|
        review.processed_rating("quality", group)
      end
      process_story_review_component(group, "review_popularity") do |review|
        review.processed_rating("popularity", group)
      end
      g_id = group.nil? ? 0 : group.id
      @processed_ratings[g_id]["confidence"] = story_confidence(group)
    end

    # used by process_story_reviews to apply the review double-weighting hullaballoo.
    # We use the review's "confidence" rating as a weight here.
    def process_story_review_component(group, component_id)
      weight_value_pairs = []
      @story.public_reviews_for_ratings.each do |review|
        if group.nil? || review.member.belongs_to_group?(group)
          value = yield(review)
          weight_value_pairs.push({:value => value, :weight => review.processed_rating("confidence", group) || DEFAULT_CONFIDENCE}) if value
        end
      end
      g_id = group.nil? ? 0 : group.id
      @processed_ratings[g_id][component_id] = Ratings::do_weighted_average(weight_value_pairs)
    end

    # Derive story rating confidence based on the confidence of each member review, scaled down
    # based on the number of reviews. The amount it's scaled down is determined by the threshold for "full confidence".
    # e.g. if the story has 5+ reviews, the coeff will be 1; otherwise it will be less.
    def story_confidence(group)
      if @story.public_reviews_for_ratings.empty?
        return nil
      else
        n = 0
        review_confidence_ratings = @story.public_reviews_for_ratings.map { |r| 
          if group.nil? || r.member.belongs_to_group?(group)
            n += 1
            r.processed_rating("confidence", group) || DEFAULT_CONFIDENCE
          end
        }.compact
        unscaled_confidence = Ratings::do_average(review_confidence_ratings) || 0
        num_reviews_coeff = (n.to_f / SocialNewsConfig["num_reviews_for_full_confidence"]).constrain(0..1)
        return unscaled_confidence * num_reviews_coeff
      end
    end

    # Story popularity is currently an unweighted mash-up of "popularity" ratings (i.e. "recommendation")
    # plus a few "stats", i.e. numbers scaled to 1-5.
    def process_story_popularity(group)
      g_id = group.nil? ? 0 : group.id
      weight_value_pairs = []
      SocialNewsConfig["story_rating_popularity_components"].each do |key, component|
        if component["type"] == "auto"
          # SSS: Right now, story popularity is not computed on a per-group basis
          # So, the value will be identical for all groups and be the same as sitewide popularity
          value = scale_stat(@story.send(component["attribute"]), component["scale"])
          @processed_ratings[g_id][key] = value # store this off here for display
        elsif key == "review_popularity"
          value = @processed_ratings[g_id]["review_popularity"]
        end
        weight_value_pairs.push({:value => value, :weight => component["weight"] }) if value
      end
      @processed_ratings[g_id]["popularity"] = Ratings::do_weighted_average(weight_value_pairs)
    end

    # helper
    def scale_stat(unscaled_value, scale)
      (unscaled_value.to_f / scale * 5).constrain(1..5)
    end

    # do story average for each criterion. just in SQL, not weighted in any way...
    def process_story_individual_criteria(group)
      joins = "JOIN reviews ON ratings.ratable_id=reviews.id"
      conditions = {
          'reviews.story_id' => @story.id,
          'reviews.status' => ["list", "feature"],
          'ratings.criterion' => Rating.criteria_keys_by_type("quality") + Rating.criteria_keys_by_type("popularity"),
          'ratings.ratable_type' => Review.name}
      if group.nil?
        g_id = 0
      else
        g_id = group.id
        joins += " JOIN memberships on memberships.member_id=reviews.member_id"
        conditions.merge!({"memberships.membershipable_type" => 'Group', "memberships.membershipable_id" => g_id})
      end
      Rating.average(:value, :joins => joins, :conditions => conditions, :group => 'criterion').each do |criterion, rating|
        @processed_ratings[g_id][criterion] = rating
      end
    end
  end
end
