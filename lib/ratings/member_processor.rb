module Ratings
  class MemberProcessor < Processor
    # online_request: this is a request that originated from a web http request => minimal processing
    # if not, it is an offline request, and we can take all the time in the world
    def initialize(member, online_request, group)
      @member = member
      # In the general / common case, we have to compute member ratings for all social groups that the member belongs to
      @groups = group ? [group] : (online_request ? [] : member.social_groups)
    end

    # calculate rating components, store them & weighted average
    def process
      @member.update_review_stats
      @member.update_metareview_stats
      # SSS: We want to bypass AR callbacks to avoid getting stuck in an infinite callback loop!
      # So, use update_all instead of update!
      Member.update_all("total_reviews = #{@member.total_reviews}, total_answers = #{@member.total_answers}", :id => @member.id)

      weight_value_pairs = []
      @processed_ratings = {}
      ([nil] + @groups).each { |group|
        gid = group.nil? ? 0 : group.id
        @processed_ratings[gid] = {}
        SocialNewsConfig["member_level_components"].each do |key, component|
          value = send("member_" + key, group) || 1 # one by default
          weight_value_pairs.push({:value => value, :weight => component["weight"]})
          @processed_ratings[gid][key] = value
        end

        # now store weighted average
        @processed_ratings[gid]["overall"] = Ratings::do_weighted_average(weight_value_pairs)
      }
      return @processed_ratings
    end


    # Individual Member Level Components

    # member 'activity': get total number of Ratings, apply to logarithmic scale
    def member_activity(group)
      answers_count_min_one = @member.total_answers.zero? ? 1 : @member.total_answers
      return (Math.log(Math.exp(5) * answers_count_min_one / SocialNewsConfig["member_level_activity_max_num_answers"])).constrain(1..5)
    end

    # member metareviews: truly the heart of the 'meta-moderation' code.
    # see also how review's aggregate ratings below (in process_review); already weighted by rater member level
    def member_meta_reviews(group)
      joins = "JOIN reviews ON processed_ratings.processable_id=reviews.id"
      conditions = { 'reviews.member_id' => @member.id, 'processed_ratings.rating_type' => "meta", 'processed_ratings.processable_type' => Review.name }
      if group
        joins += " JOIN memberships on memberships.member_id=reviews.member_id"
        conditions.merge!({"memberships.membershipable_type" => 'Group', "memberships.membershipable_id" => group.id})
      end

      return ProcessedRating.average(:value, :joins => joins, :conditions => conditions)
    end

    # base experience on member's claims in certain profile fields
    def member_experience(group)
      weight_value_pairs = []
      SocialNewsConfig["member_level_experience_components"].each do |key, component|
        value = @member.send(key.to_s + "_experience")
        weight_value_pairs.push({:value => value, :weight => component["weight"]}) if value
      end
      return Ratings::do_weighted_average(weight_value_pairs).constrain(1..5) if !weight_value_pairs.empty?
    end

    # give user points for entering profile info, extra points for not hiding it.
    # imitating the point-based system from the legacy calcTransparency here...
    def member_transparency(group)
      score_sum = score_divisor = 0

      # 1. text-based profile attributes (non-blank values are not stored in the db, so give 1pt by default)
      profile_fields = MemberAttribute.find(:all, :select => "visible", :conditions => {
        :member_id => @member.id, :name => Member.profile_flex_fields})
      score_sum += profile_fields.map{|pf| 1 + (pf.visible ? 1 : 0)}.sum
      score_divisor += Member.profile_flex_fields.size * 2

      # 2. ...and 3 extra points for length of 'about'
      about = @member.visible_attribute("about")
      score_sum += ((about.length.to_f / 200 * 8).constrain(0..8)).round if about
      score_divisor += 8

      # 3. experience components
      score_sum += SocialNewsConfig["member_level_experience_components"].keys.map do |key|
        experience_value = @member.send(key + "_experience")
        ((experience_value && !experience_value.to_i.zero?) ? 1 : 0) + 
          (@member.send("show_" + key + "_experience") ? 1 : 0)
      end.sum
      score_divisor += SocialNewsConfig["member_level_experience_components"].keys.size * 2

      # 4. associations
      score_sum += [[:source_affiliations, :show_affiliations], [:favorites, :show_favorites]].map do |assoc_keys|
        (@member.send(assoc_keys[0]).empty? ? 0 : 1) + (@member.send(assoc_keys[1]) ? 1 : 0)
      end.sum
      score_divisor += 4

      # 5. generic 'show' attributes
      show_attributes = [:show_email, :show_in_member_list]
      score_sum += show_attributes.map{|show_attribute| @member.send(show_attribute) ? 3 : 0}.sum
      case @member.show_profile			# handle the attributes that aren't true/false
      	when Member::Visibility::PUBLIC then score_sum += 3
 #     	when 'members' then score_sum += 1		# can uncomment if we add other settings (like friends or private)
      	else	score_sum += 0
      end
      case @member.public_mynews
      	when 'public' then score_sum += 3
 #     	when 'members' then score_sum += 1
      	else	score_sum += 0
      end
      score_divisor += (show_attributes.size + 2) * 3		# be sure to add number of attributes that aren't true/false

      # 6. photo
      score_sum += 3 if @member.image
      score_divisor += 3

      return (score_sum.to_f / score_divisor * 5).constrain(1..5)
    end

    def member_validation(group)
      return @member.validation_level
    end
  end
end
