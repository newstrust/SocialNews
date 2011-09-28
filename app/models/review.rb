class Review < ActiveRecord::Base
  include Status

  # Used to pass referrer code to track the source of new story reviews
  attr_accessor :referrer_code

  # Used to pass local site info on which review was created
  attr_accessor :local_site

  acts_as_processable :dependents => Proc.new { |review| [review.member, review.story.reload].compact }, :background => true
  acts_as_review

  belongs_to :story, :counter_cache => 'reviews_count'
  belongs_to :member
  has_many :meta_reviews, :dependent => :destroy
  has_many :excerpts, :dependent => :destroy, :extend => BatchAssociationExtension
  has_many :comments, :as => :commentable, :dependent => :destroy
  
  # NOTE: If you change this, change update_review_stats in member.rb too!
  named_scope :visible, :joins => "JOIN stories ON reviews.story_id=stories.id",
    :conditions => {'reviews.status' => ['list', 'feature'], 'stories.status' => ['list', 'feature']}

  validates_uniqueness_of :story_id, :scope => :member_id, :if => :not_a_guest_review?

    # These 3 methods ensure that reviews_count for the reviewed story are 
    # in sync with the reviews public status (hidden reviews shouldn't get
    # counted in the story's reviews_count)
  before_save  :record_review_status
  after_save   :update_story_review_count_if_necessary
  after_create :update_activity_score
  after_update :update_activity_entry

  def not_a_guest_review?
    !self.member.nil? 
  end
  
  def is_public?
    return (!hidden? && !member.nil? && member.is_public? && story.is_public?)
  end
  
  # reviews with certain types of disclosures may be _shown_ but should not be factored into story rating
  def include_rating?
    return (disclosure.blank? || !SiteConstants::ordered_hash("review_disclosure").select{|k, v| v["exclude_rating"]}.keys.include?(disclosure))
  end

  # Other models that implement comments check this method to determine if they should render comments
  # Reviews have them implemented by default so just return true to ensure that the views continue working
  # for all the models that have comments.
  def allow_comments?
    true
  end

  def meta_review_by_member(member)
    MetaReview.find_or_initialize_by_review_id_and_member_id(self.id, member.id) if member
  end

  def meta_reviews_from_group(g)
    if g.nil? 
      meta_reviews 
    else
      MetaReview.find(:all, :joins => "JOIN memberships on memberships.member_id=meta_reviews.member_id", :conditions => {"memberships.membershipable_type" => "group", "memberships.membershipable_id" => g.id, :review_id => self.id})
    end
  end
  
  # find corresponding source review, to be used in processing.
  # use virtual attribute to make ajax overall_rating call work
  def source_review
    @source_review || (SourceReview.find_by_source_id_and_member_id(self.story.primary_source.id, self.member.id) if self.story && self.story.primary_source  && self.member)
  end
  def source_review=(temp_source_review)
    @source_review = temp_source_review
  end
  
  # for batch_autocomplete
  def excerpts_attributes=(excerpts_attributes)
    excerpts.attributes_collection = excerpts_attributes.reject{|ea| ea["body"].blank? and ea["comment"].blank? and ea["should_destroy"]=="false" }
  end
  
  # bind these to review so that we can use review logic to decide whether or not to show them...?
  def story_relations
    story.story_relations.select{|sr| sr.member==member}
  end
    
  def is_featured
    constants = SocialNewsConfig["featured_reviews"]
    return ((status == "feature") ||  (
      (comment && (comment.length > constants["min_comment_length"])) &&
      (member_rating >= constants["min_member_rating"]) &&
      (ratings.length > constants["min_ratings_count"]) && 
      (processed_rating("meta").nil? || (processed_rating("meta") >= constants["min_meta_rating"]))))
  end
  
  def num_answers
    ratings.length + (comment.blank? ? 0 : 1) + (personal_comment.blank? ? 0 : 1) + (excerpts.empty? ? 0 : excerpts.length)
  end

  def should_count_towards_review_count?
    is_public? && include_rating?
  end

  private

  def update_activity_score
    if should_count_towards_review_count?
      ActivityScore.boost_score(self.story, :review, {:member => self.member, :obj => self, :url_ref => self.referrer_code})
    end
  end

  # SSS: I am using before_save and after_save to monitor change in status of a review and update story count!
  # This solution uniformly handles all changes to status of reviews everywhere!
  def record_review_status
      # This load will come from the cache (the per-request cache that rails maintains)
    r = self.id ? Review.find(self.id) : nil
    @should_count_before_save = r ? r.should_count_towards_review_count? : should_count_towards_review_count?
    return true
  end

  def update_story_review_count_if_necessary
      # Increment / decrement the reviews_count value depending on the new publicness status of the review!
    should_count_after_save = should_count_towards_review_count?
    Story.update_reviews_count(self.story_id, should_count_after_save == true ? 1 : -1) if (should_count_after_save != @should_count_before_save)
  end

  def update_activity_entry
    # SSS FIXME: Hack with a time range check.  Why is this being called at all if the review object is not updated in the first place??
    if self.member_id && (Time.now - self.updated_at < 5.minutes)
      ae = ActivityEntry.find(:first, :conditions => {:member_id => self.member_id, :activity_type => 'Review', :activity_id => self.id})
      if ae.nil?
        logger.error "Could not find activity entry for review #{self.id} for member #{self.member_id}.  Creating new one!"
        ActivityEntry.create(:member_id => self.member_id, :activity_type => 'Review', :activity_id => self.id, :created_at => self.created_at)
      else
        ae.update_attribute(:updated_at, Time.now)
      end
    end
  end

  def self.show_staff_reviews?(local_site, page_obj)
    # Selectively turn off no-staff-reviews constraint.
    # -------------------------------------------------------------------------------------
    # The constraints get turned off in 10-min blocks, and sometimes in a 20-minute block
    # If 'n' is the # of 10-min blocks within an hour that get their constraints turned off,
    # then you can run the following code to see how the pattern plays out in a week:
    #    x = (0..7).collect { |d| (0..23).collect { |h| (0..59).collect { |m| m%10 == 0 ? ((d+h+m/10)% 9 < 2 ? 1 : 0) : nil }.compact } }.flatten
    #    x.each_slice(6).each { |s| puts "#{s.inject(0) { |t,i| t+i}}: #{s.join}" }
    # -------------------------------------------------------------------------------------
    t = Time.now
    pg_id = page_obj ? page_obj.id : 0
    ((t.day + t.hour + pg_id + t.min/10) % 9 < (local_site ? 3 : 2))
  end

  def self.featured_review(local_site=nil, page_obj=nil)
    joins = []
    joins << ["JOIN members ON reviews.member_id = members.id"]
    joins << ["JOIN stories ON reviews.story_id = stories.id"]

    conditions = []
    conditions << ["stories.status IN (?)", [Story::LIST, Story::FEATURE]]
    conditions << ["members.status = ?", Member::MEMBER]
    conditions << ["members.rating >= ?", SocialNewsConfig["min_trusted_member_level"]]
    conditions << ["members.validation_level >= ?", SocialNewsConfig["min_trusted_member_validation_level"].to_i]
    conditions << ["length(reviews.comment) >= ?", local_site ? 50 : 100]
    # SSS: Starting July 2011, we dont have this constraint anymore since staff activity is going to be reduced
    # conditions << ["reviews.member_id NOT IN (?)", Member::ACTIVE_STAFF_IDS] unless show_staff_reviews?(local_site, page_obj)

    # page_obj constraints
    if page_obj.is_a?(Topic)
      joins << "JOIN taggings t2 on stories.id = t2.taggable_id AND t2.taggable_type = 'Story' AND t2.tag_id = #{page_obj.tag_id}"
    elsif page_obj.is_a?(Group)
      joins << "JOIN group_stories gs on stories.id = gs.story_id AND gs.group_id = #{page_obj.id}"
    end

    # meta rating constraints -- either no one has rated it, or if rated, it has a minimum rating of 3
    joins << "LEFT JOIN processed_ratings ON processable_type='Review' AND processable_id = reviews.id AND rating_type='meta'"
    conditions << ["processed_ratings.id IS NULL OR processed_ratings.value >= 3.0"]

    # local_site constraints
    if local_site
      joins << "JOIN taggings on stories.id = taggings.taggable_id AND taggings.taggable_type = 'Story' AND taggings.tag_id = #{local_site.constraint.id}"
    else
      conditions << ["stories.is_local IS NULL OR stories.is_local = ?", false]
    end

    Review.find(:all,
                :from       => "reviews USE INDEX (index_reviews_on_created_at_and_member_id)",
                :joins      => joins * ' ', 
                :conditions => QueryHelpers.conditions_array(conditions),
                :order      => "reviews.created_at DESC",
                :limit      => 1).first
  end

  def self.recent_reviews(how_many=5, opts={})
    opts[:local_site] ||= nil
    opts[:max_per_member] ||= 1
    opts[:only_with_notes] ||= false

    max_per_member  = opts[:max_per_member]
    only_with_notes = opts[:only_with_notes]
    local_site      = opts[:local_site]

    results        = []
    conditions     = "reviews.member_id IS NOT NULL AND reviews.status IN ('list', 'feature')"
    conditions    += " AND reviews.comment != ''" if only_with_notes
    member_id_hash = {}
    story_id_hash  = {}

    join_str = "JOIN stories ON reviews.story_id=stories.id AND stories.status in ('#{Story::LIST}', '#{Story::FEATURE}')"
    if local_site
      join_str += " JOIN taggings on stories.id = taggings.taggable_id && taggings.taggable_type = 'Story'"
      conditions += "#{conditions.blank? ? '' : ' AND '}taggings.tag_id = #{local_site.constraint.id}"
    else
      conditions += " AND (stories.is_local IS NULL OR stories.is_local = false)"
    end

    exclude_conditions = ""
    num_attempts = 0
    while (num_attempts < 10) do
      num_attempts += 1

      # Do not join members table on validation level here -- leads to a slow query!
      # More often than not, right now, reviews tend to be from level 3 members anyway -- so, we can filter this in ruby.
      candidates = Review.find(:all,
                               ## Hint to use the index -- because some other index is being used which leads to a sort!
                               :from => "reviews USE INDEX (index_reviews_on_created_at_and_member_id)",
                               :joins => join_str,
                               :conditions => "#{conditions}#{exclude_conditions.blank? ? '' : ' AND '}#{exclude_conditions}",
                               :order => "reviews.created_at DESC",
                               :limit => how_many * (max_per_member ? 5 : 1))

      break if candidates.empty?

      # No constraint on max reviews per member
      if (max_per_member.nil?)
        results = candidates
        break
      end

      candidates.each { |r|
        # Skip this candidate if:
        # 1. the reviewer doesn't have the required validation level
        # IMPORTANT: Add these members to the hash -- otherwise you can wont make forward progress and can get stuck in an infinite loop!
        if r.member.nil? || (r.member.validation_level < SocialNewsConfig["min_trusted_member_validation_level"].to_i)
          member_id_hash[r.member_id] = max_per_member+1
          next
        end

        # Skip this candidate if:
        # 2. we have processed the member
        # 3. this is a story we've already added to the result set
        next if member_id_hash[r.member_id] && (member_id_hash[r.member_id] >= max_per_member) || story_id_hash[r.story_id]

        # Add r to the result set
        results << r
        member_id_hash[r.member_id] ||= 0
        member_id_hash[r.member_id] += 1
        story_id_hash[r.story_id] = 1
        break if results.size == how_many
      }

      # Are we done?
      break if (results.size == how_many)

        # No!  Go back and fetch more reviews!
      mkeys = member_id_hash.keys
      skeys = story_id_hash.keys
      exclude_conditions  = mkeys.empty? ? "" : "reviews.member_id NOT IN (#{mkeys * ','})"
      exclude_conditions += "#{exclude_conditions.blank? ? '' : ' AND '}reviews.story_id NOT IN (#{skeys * ','})" if !skeys.empty?
    end

    return results
  end
  
  def self.find_member_reviews(member, show_hidden, options = {})
    options[:page] ||= 1
    options[:per_page] ||= 10
    
    # Because no way (yet) to specify non-equality conditions via hashes
    conditions = ["reviews.member_id = ?", member.id]
    conditions[0] += " AND reviews.status IN ('list', 'feature') AND stories.status IN ('list', 'feature')" unless show_hidden
    conditions[0] += " AND reviews.comment != ''" if options.delete(:commented_only)
    
    return Review.paginate(options.merge(:joins => "JOIN stories ON reviews.story_id=stories.id",
      :conditions => conditions, :order => "updated_at DESC"))
  end

  def self.process_pending_notifications(pns_by_member_hash, action)
    pns_by_member_hash.each { |m_id, pns|
      begin
        m = Member.find(m_id)
        reviews = pns.map(&:trigger_obj)
        h = {}
        reviews.each { |r| s = r.story; h[s.id] ||= []; h[s.id] << r }
        num_reviews = reviews.length
        num_stories = h.keys.length
        puts "Sending review notification digest to #{m.name}: #{num_stories} stories and #{num_reviews} reviews are involved"
        NotificationMailer.deliver_review_notifications_digest(:to_member => m, :body => { :to => m, :reviews => reviews, :story_hash => h, :num_stories => num_stories, :num_reviews => num_reviews })

        # Remove all notifications
        pns.map(&:destroy)
      rescue Exception => e
        output = "Exception #{e} trying to send #{action} notification digest to #{m.id}; Backtrace: #{e.backtrace * '\n'}"
        puts output
        RAILS_DEFAULT_LOGGER.error output
      end
    }
  end
end
