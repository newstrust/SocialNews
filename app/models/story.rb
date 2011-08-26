class Story < ActiveRecord::Base
  NEWS        = "news"
  OPINION     = "opinion"
  OTHER       = "other"
  STORY_TYPE  = { "" => "", NEWS => "News", OPINION => "Opinion" }

    # Story rating types
  UNRATED     = "unrated"
  RATED       = "rated"
  TRUSTED     = "trusted"       
  UNTRUSTED   = "untrusted"       

    # Story status
  PENDING     = "pending"
  HIDE        = "hide"
  LIST        = "list"
  FEATURE     = "feature"
  QUEUE       = "queue"

  ALL_STATUS_VALUES = [PENDING, HIDE, LIST, FEATURE, QUEUE]  # no STUB here!

    # Some constants used to optimize common listing queries
    # If you modify this in any way, update code in app/models/source.rb:update_story_types
  MSM_NEWS    = 1
  IND_NEWS    = 2
  MSM_OPINION = 3
  IND_OPINION = 4

  LEAST_TRUSTED_TIMESPAN = 90 # 90 days time window for least trusted story listings

    # Required fields for listed stories
  LISTED_STORY_REQD_FIELDS = [ "url", "title", "story_type", "status", "story_date", "excerpt", "editorial_priority", "authorships", "topic_or_subject_taggings" ]

    # NOTE: There is no story_scope field in story.  This is just a decoration of the is_local flag on the story object.
    # So, if you want to add a new value to this, you probably would have to get rid of the 'is_local' flag and replace
    # it with a 'story_scope' field, or use the "scope" attribute that exists already (but, need to verify it is not being
    # used for some other purpose)
  module StoryScope
    LOCAL = "local"
    NATIONAL = "national"
    ALL = [LOCAL, NATIONAL]
  end

    # Edit form versions
  SHORT_FORM    = "short"
  QUICK_FORM    = "quick"
  FULL_FORM     = "full"
  ADVANCED_FORM = "advanced"
  EDIT_FORM_RANKS = { SHORT_FORM => 1, QUICK_FORM => 2, FULL_FORM => 3, ADVANCED_FORM => 4 }

    # SSS: Move this to a constants file
    # Minimum form levels at which story fields are shown for editing
  FORM_FIELD_MIN_LEVELS = { :title                => SHORT_FORM,
                            :subtitle             => FULL_FORM,
                            :excerpt              => QUICK_FORM,
                            :journalist_names     => QUICK_FORM,
                            :story_scope          => FULL_FORM,
                            :story_type_condensed => SHORT_FORM,
                            :story_type_expanded  => FULL_FORM,
                            :story_type           => SHORT_FORM,  # story_type is always visible in the form of either the expanded /condensed version
                            :content_type         => FULL_FORM,
                            :authorships          => QUICK_FORM,
                            :taggings             => SHORT_FORM,
                            :story_date           => QUICK_FORM,
                            :editorial_priority   => FULL_FORM,
                            :url                  => FULL_FORM }
  
  @@stat_count_attributes = %w(number_sources anonymous_sources number_viewpoints opinions_as_facts number_stakeholders stakeholders_quoted)
  cattr_reader :stat_count_attributes
  @@stat_word_count_attributes = %w(derogatory_words complimentary_words)
  cattr_reader :stat_word_count_attributes
  
  acts_as_processable :dependents => Proc.new { |story| story.reload.sources }, :background => true
  acts_as_taggable :after_add => :update_subject_taggings_after_add, :after_remove => :update_subject_taggings_after_delete

  has_one :image, :as => :imageable, :dependent => :destroy
  has_one :video, :dependent => :destroy
  has_many :authorships, :extend => BatchAssociationExtension, :order => "authorships.id", :dependent => :destroy
  has_many :sources, :through => :authorships, :order => "authorships.id"
  has_many :story_feeds, :dependent => :delete_all
  has_many :feeds, :through => :story_feeds
  belongs_to :submitted_by_member, :foreign_key => "submitted_by_id", :class_name => "Member"
  belongs_to :edited_by_member, :class_name => "Member"
  has_many :reviews
  has_many :story_relations, :extend => BatchAssociationExtension, :dependent => :delete_all
  has_many :related_stories, :through => :story_relations, :source => :related_story
  has_many :saves, :class_name => "Save"
  has_many :page_views, :as => :viewable, :dependent => :delete_all
  has_many :newsletter_stories
  has_many :newsletters, :through => :newsletter_stories
  has_many :urls, :class_name => "StoryUrl", :extend => BatchAssociationExtension, :dependent => :delete_all
  has_many :story_clicks, :dependent => :delete_all
  has_many :comments, :as => :commentable, :dependent => :destroy
  has_many :group_stories
  has_many :groups, :through => :group_stories
  has_many :short_urls, :as => :page, :dependent => :delete_all

    ## IMPORTANT: If you make any changes to these flex attribute storage, make appropriate fixes to "metadata_update_time"
    ## autolist score, its components, as well as api info fetched from different apis, and lib/feed_parser.rb
  @@autosubmit_attributes = FeedFetcher::Score::SCORE_COEFFICIENTS.keys.collect { |k| "autolist_#{k.to_s}" } + MetadataFetcher::APIS.keys.collect { |api| api.to_s + "_info" } + ["debug_excerpt"]

  has_eav_behavior :fields => @@stat_count_attributes + @@stat_word_count_attributes + @@autosubmit_attributes + [
                    "body", "full_text", "duplicate_links", "country",
                    "state", "location", "scope", "edit_notes", "online_access",
                    "referred_by", "submit_story_form"]

  after_create :init_activity_score
  before_save :set_cached_and_computed_values

  acts_as_textiled :discussion_description
  #acts_as_textiled :excerpt  #FIXME: Need to revisit this

  # member_review ... temporarily used by the member reviews widget
  # found_duplicate_*_association ... used during story updates to record information about exceptions!
  attr_accessor :member_review, :found_duplicate_authorship_association, :found_duplicate_tagging_association

  # Used to pass local site on which the story is being manipulated
  # attr_accessor :local_site

  # Used to pass referrer code to track the source of new story posts
  attr_accessor :referrer_code

  # We are no longer forcing update failures when info is missing
  # So, we cannot use model.errors to record validation errors. 
  attr_accessor :update_errors

  define_index do    
    # Fields
    indexes :title, :sortable => true
    indexes :subtitle 
    indexes :excerpt
    indexes :journalist_names
    indexes :tag_aggregate, :as => :tags

    # Attributes
    has rating
    has status
    has story_date
    has created_at, :as => :sort_field
  end

  # basic validation which applies to feedfetcher & user-submitted stories
  validates_presence_of :title
  validates_presence_of :story_date, :message => "must match publication date"
  validates_presence_of :url
  validates_format_of :url, :with => /https?:\/\/[a-zA-Z0-9.-](:\d+)?\/?[^:]*/, :message => "for the posted story is invalid."
  validates_uniqueness_of :url, :message => "Another story with this url exists"

  def field_is_visible?(member, field)
    EDIT_FORM_RANKS[member.preferred_edit_form_version] >= EDIT_FORM_RANKS[FORM_FIELD_MIN_LEVELS[field]]
  end
  
  # overwrite validate as there are different requirements for user-entered stories & feedfetcher ones
  # let editors hide a pending story w/o requiring validations, though!
  def validate
    super
    m = edited_by_member

    # Check if we are assigning alternate urls that is used by another story
    self.urls.each { |u|
      s = Story.find_by_url(u.url)
      if s
        if m && m.has_role_or_above?(:editor)
          errors.add("urls", "There is <a href='/stories/#{s.id}'>another story (id #{s.id})</a> with url #{u.url}.  Please remove this url from the list of alternate urls in the edit form below.  Or <a href='/admin/stories/merge_tool'>merge the two stories via the story merge tool (this story: #{self.id}, other story: #{s.id})</a>")
        else
          errors.add("urls", "Your edits cannot be saved because of url conflicts.  Please email editors about this story (id: #{s.id}).")
        end
      end
    }

    nt_tagger_id = Member.nt_tagger.id
    if m && (m != Member.nt_anonymous) && (m != Member.nt_bot) && (status != HIDE)
      # Only record errors appropriate to the fields that are visible in the edit form that the member picked
      @update_errors = []
      @update_errors << "No topics selected"     if taggings.reject { |t| t.member && (t.member.id == nt_tagger_id) }.empty? && field_is_visible?(m, :taggings)
      @update_errors << "No sources selected"    if authorships.empty? && field_is_visible?(m, :authorships)
      @update_errors << "No story type selected" if story_type.blank?  && field_is_visible?(m, :story_type)
      @update_errors << "Quote is empty"         if excerpt.blank?     && field_is_visible?(m, :excerpt)
    end
  end

  def destroy
    if (self.reviews_count > 0)
      raise Exception.new("The story has some existing public reviews!  Delete those public reviews before attempting to delete the story.")
    elsif (self.saves_count > 0)
      raise Exception.new("The story has been liked/saved by members!  Delete all those saves before attempting to delete the story.")
    elsif (self.newsletter_stories.count > 0)
      raise Exception.new("The story has some existing newsletter stories!  Delete those newsletter stories before attempting to delete the story.")
    elsif (self.related_stories_reciprocal.size > 0)
      raise Exception.new("The story is linked to another story!  Delete the story relations before attempting to delete the story")
    end

      # Delete the non-public reviews
    self.reviews.each { |r| r.destroy }

      # All's well.  Proceed as planned!
    super
  end
  
  # Fill in basic story metadata.
  def self.autopopulate_fields(story, url)
    NetHelpers.set_http_timeout(10)  ## 10 second http timeout; FIXME ... Use a constant from a yaml file?
    extra_info = StoryAutoPopulator.populate_story_fields(story)

    # The story auto populator might change the url, so check if there is a story in the db with the new url 
    story = Story.check_for_duplicates(story.url) || story if story.url != url

    # Populate required fields so that story save succeeds!
    story.title = " -- Please fill in story title -- " if story.title.blank?
    
    return story, extra_info
  end

  # Other models that implement comments check this method to determine if they should render comments
  # Stories have them implemented by default so just return true to ensure that the views continue working
  # for all the models that have comments.
  def allow_comments?
    true
  end

  # returns subjects (NOT topics) for this story.
  def subject_tags
    # SSS: Always use the taggings association (rather than the 'tags' :through association which will fetch results from the db)
    # so that this returns the results that rely on the in-memory taggings collection which may be different from the in-db
    # taggings collections (for the scenario when new taggings are added in-memory not committed to the db yet)
    taggings.map(&:tag).select{|t| t.tag_type == Tag::SUBJECT}
  end

  # returns topics (NOT subjects) for this story.
  def topic_tags
    # SSS: Always use the taggings association (rather than the 'tags' :through association which will fetch results from the db)
    # so that this returns the results that rely on the in-memory taggings collection which may be different from the in-db
    # taggings collections (for the scenario when new taggings are added in-memory not committed to the db yet)
    taggings.map(&:tag).select{|t| t.tag_type == Tag::TOPIC}
  end

  def topics(local_site)
    Topic.tagged_topics_or_subjects(topic_tags, local_site)
  end

  def subjects(local_site)
    Topic.tagged_topics_or_subjects(subject_tags, local_site)
  end

  def belongs_to_site?(local_site)
    local_site.nil? || Tagging.exists?(:taggable_id => self.id, :taggable_type => self.class.name, :tag_id => local_site.constraint_id)
  end

  def public_topics(local_site=nil)
    topics(local_site).select{|t| t.is_public?}.compact
  end

  def topic_or_subject_taggings
    taggings.select { |t| t.tag.is_topic_or_subject_tag? }
  end

  def topic_or_subject_tags
    taggings.map(&:tag).select { |t| t.is_topic_or_subject_tag? }
  end

  def add_feed_tags(feed_tags)
    nt_bot = Member.nt_bot
    t1 = (feed_tags | []).map { |c| Tag.curate(c.downcase) }
    t2 = t1.collect { |t| MetadataFetcher.get_mapped_topics(t) }.compact.flatten # Try to see if we can find a match for any of these tags in our taxonomy 
    t3 = self.taggings.find_all_by_member_id(nt_bot.id).map { |t| t.tag.name.downcase }
    t4 = Tagging.find(:all, 
                      :joins => "JOIN topics ON topics.tag_id = taggings.tag_id",
                      :conditions => ["taggings.member_id != ? AND taggings.taggable_type = 'Story' AND taggings.taggable_id = ?", nt_bot.id, self.id]).map { |t| t.tag.name.downcase }

      # 1. Add new tags from this feed (t1)
      # 2. Add new topic/subject tags which we found in our taxonomy (t2)
      # 3. Add existing tags from nt_bot (t3)
      # 4. Remove tags that correspond to existing story topics/subjects (t4)
      # 5. Uniq, quote and tag!
    self.tag_list = { :tags => (t1 + t2 + t3 - t4).uniq.collect { |t| Tag.quote(t) }.join(","), :member_id => nt_bot.id }
  rescue Exception => e
    t1 ||= []; t2 ||= []; t3 ||= []; t4 ||= []
    logger.error "Exception #{e}: t1 - #{t1 * ','}, t2 - #{t2 * ','}, t3 - #{t3 * ','}, t4 - #{t4 * ','}, combined - #{(t1+t2+t3-t4).uniq * ','}"
  end

    # Optimized code that doesn't load/join unnecessary crud
  def reviewer_ids
    Review.find(:all, :conditions => {:story_id => self.id}, :select => "member_id").map { |r| r.member_id }
  end

  def is_queued?
     m = submitted_by_member 
     (status == QUEUE) and (m.nil? || m == Member.nt_bot)
  end

  def api_metadata(api)
    @metadata ||= {}
    v = @metadata[api]
    if (v.nil?)
      v_str = self.send(api.to_s + "_info") # Fetch from db
      if (!v_str.nil?)
          # convert hex nibbles to binary and then unmarshall the binary data
        v = Marshal.load([v_str].pack("H*"))
        @metadata[api] = v # cache it
      end
    end
    v
  rescue Exception => e
    nil
  end

  ## IMPORTANT: This method assumes that the api info is stored as flex attributes
  def metadata_update_time(api)
    md = StoryAttribute.find(:first, :conditions => { :story_id => self.id, :name => "#{api}_info" })
    md ? md.updated_at : nil
  end

  def record_api_metadata(api, v)
    if v
      key = api.to_s + "_info"

      # since marshalling generates binary data .. convert it to hex nibbles using unpack
      # because I am lazy to create a new binary table for api info
      v_dump = Marshal.dump(v).unpack("H*")[0]

      # If the attribute exists in the db, update it! (flex attributes doesn't seem to do it on its own)
      if StoryAttribute.exists?(:story_id => self.id, :name => key)
        self.send("#{key}=", v_dump)
      else
        self.update_attributes({key => v_dump})
      end
    end
  end

  def member_tags
    tags.find(:all, :joins => "LEFT JOIN topics ON topics.tag_id=tags.id", :conditions => "topics.id IS NULL")
  end

  def is_pdf?
    url =~ /.pdf\s*$/
  end

  def is_public?
      # IMPORTANT: When you change this, also change the code in self.is_public_sql_clause below
    [LIST, FEATURE].include?(self.status)
  end

  def is_visible?
    [LIST, FEATURE, PENDING, QUEUE].include?(self.status)
  end

  def is_unpublished?
    [PENDING, QUEUE].include?(self.status)
  end

  # "Framebuster" sites are an obnoxious bunch which reject our toolbar.
  # In these cases, the user needs to click one more time (to get around popup blockers)
  # to get to the popup version of the toolbar.
  def from_framebuster_site?
    self.primary_source ? self.primary_source.is_framebuster : StoryAutoPopulator::FRAMEBUSTER_DOMAINS.include?(NetHelpers.get_url_domain(self.url))
  end

  # If the story has not been edited by anyone, and there no reviews yet, we consider it unvetted
  def is_unvetted?
    edited_by_member.nil? && (reviews_count == 0)
  end

  def is_rated?
    [LIST, FEATURE].include?(status) && (reviews_count >= 3)
  end

  def can_be_listed?
    LISTED_STORY_REQD_FIELDS.find { |f| self.send(f).blank? }.nil?
  end

  def empty_field_list
    LISTED_STORY_REQD_FIELDS.select { |f| self.send(f).blank? }
  end

  def has_embedded_video?
    self.video && !self.video.embed_code.blank?
  end

  def public_reviews
    reviews.select{ |r| r.is_public? }.compact
  end
  def public_reviews_for_owner(member)
    reviews.select{|r| r.is_public? or r.member==member}.compact
  end
  def public_reviews_for_ratings
    public_reviews.select{|r| r.include_rating?}
  end

  def shared_reviews_count(target)
    Sharable.count(:joins => "JOIN reviews ON reviews.story_id = #{self.id} AND reviews.id = sharables.sharable_id AND sharables.sharable_type = 'Review' AND sharable_target = '#{target}'")
  end

  def num_diggs
    if @num_diggs.nil?
      digg_info = self.api_metadata(:digg)
      @num_diggs = digg_info ? digg_info[:digg_count] : 0
    end
    @num_diggs
  end

  def num_tweets
    if @num_tweets.nil?
      tm_info = self.api_metadata(:tweetmeme)
      @num_tweets = tm_info ? tm_info[:tweet_count] : nil
    end
    @num_tweets
  end
 
  # type_category is like the story's supertype: news/opinion/other. default to news--right?
  #
  def type_category
    # special case for blog_post story types -- no longer supported, but present on some legacy bookmarklets
    return OPINION if self.story_type == "blog_post"

    self.story_type.blank? ? OTHER : SiteConstants::ordered_hash("story_story_type")[self.story_type]["category"]
  rescue Exception => e
    logger.error "Caught exception trying to find story type category for #{self.story_type}. Assuming OTHER type category"
    OTHER
  end

  def short_url(local_site=nil, url_type=nil)
    su = self.short_urls.find(:first, :conditions => {:local_site_id => local_site ? local_site.id : nil, :url_type => url_type })
    su ? su.short_url : nil
  end

  # TODO: use acts_as_network or something here... for now, do it the cheap way
  def related_stories_reciprocal
    (related_stories +
      StoryRelation.find(:all, :conditions => {:related_story_id => id}).map(&:story)
      ).uniq.compact
  end

  def self.is_public_sql_clause(tbl_name = "stories")
      # IMPORTANT: When you change this, also change the code in is_public? above
    "(#{tbl_name}.status = '#{Story::LIST}' OR #{tbl_name}.status = '#{Story::FEATURE}')"
  end

  def self.update_reviews_count(story_id, n)
    Story.update_all("reviews_count = reviews_count + #{n}", :id => story_id)
  end

  def self.check_for_duplicates(url)
    s = find_by_url(url)
    if s.nil? || s.status == HIDE
        ## IMPORTANT: Add :readonly => false, otherwise the returned story is marked readonly because of the join string!
      s = find(:first, :joins => "JOIN story_urls ON stories.id=story_urls.story_id", :readonly => false, :conditions => ["story_urls.url = ?", url]) || s
    end
    if s.nil?
        # FIXME: This might not be sufficient
      src = Source.find_by_domain(NetHelpers.get_url_domain(url))

        # FIXME: Hack for Washington post for now.  In future, this should become generic, much like the custom_story_populator code ...
      if (src && (src.name == "Washington Post"))
        url_has_referrer_param = (url =~ /referrer/)
          # Either strip the referrer param or add it in, as necessary
        url2 = url_has_referrer_param ? url.gsub(/\?.*/, '') : "#{url}?referrer=#{SocialNewsConfig["app"]["slug"]}"
        s = find_by_url(url2)

          # Change the url of the existing story to use the referrer param
        if (s and url_has_referrer_param)
          s.url = url
          begin
            s.save!
          rescue Exception
            logger.error "Exception changing Wash Po story url from #{url2} to #{url}"
          end
        end
      end
    end

    return s
  end

  # NOTES: 
  # Whenever you modify this code, please make sure the corresponding checks in hide_rating method is consistent
  def self.get_rating_check_clause(rating_class, for_group=false)
    table_name = for_group ? "group_stories" : "stories"
    case rating_class
      when nil, ""   then ""
      when RATED     then "(#{table_name}.reviews_count >= #{SocialNewsConfig["min_reviews_for_story_rating"]})"
      when UNRATED   then "(#{table_name}.reviews_count < #{SocialNewsConfig["min_reviews_for_story_rating"]})"
      when TRUSTED   then "(#{table_name}.rating >= #{SocialNewsConfig["min_rating_for_top_story"]})"
      when UNTRUSTED then "(#{table_name}.rating < (#{SocialNewsConfig["min_rating_for_top_story"].to_i-0.05}))"
    end
  end

  # list_stories - Master (monster) story listing call
  #
  # This should be used wherever story listings are required!
  # includes all possible filters, sorts, pagination, you name it.
  #
  # This code essentially implements the following story listing model
  #
  #     L = sort(filter(A, F), S)    or    A ----> Filters F ---> Sorts S  ---> L
  #
  # where A is the set of all stories, F is a set of unordered filters, S is a set of ordered sorts, and L is the output listing
  #
  # Stories are listed by making a call: 
  #
  #    Story.list_stories(options)
  #
  # where options is an options hash.  The story listing code checks for the following keys within this hash:
  #
  #   :count_only    => ... (if true, returns the count, not the actual listing!) 
  #   :listing_type  => ... 
  #   :sort_orders   => ...      
  #   :filters       => ... 
  #   :start_date    => ...
  #   :time_span     => ...
  #   :end_date      => ...
  #   :paginate      => ...
  #   :per_page      => ... 
  #   :page          => ...
  #   :fill_story_window => ...
  #   :more_conditions => ...
  #   :include       => list of associations that should be loaded immediately
  #   :select        => fields to select
  #
  # :listing_type specifies either predefined listing types OR a custom listing type
  #     :most_recent    --> recent stories     (stories are ordered by most recent + top_rated first)
  #     :most_trusted   --> most trusted       (stories with at least 3 reviews and a rating of over 3 are picked, and ordered by most recent first)
  #     :for_review     --> stories for review (stories that have fewer than 3 reviews are picked, and ordered by most recent first)
  #     :recent_reviews --> stories recently reviewed
  #     :queued_stories --> stories that were automatically selected for listing by the feed fetcher
  #     :all_rated_stories  --> all rated stories
  #     :my_news        --> listing used for my news
  #     :custom         --> this is a custom listing type, and all filters and sort orders will be specified as input parameters
  #                         for this listing type, some value of :sort_orders is expected.  If not, the result listing will be whatever 
  #                         the database returns!
  #                         Note that for the custom listing type, :max_stories_per_source will not be respected!
  #
  # :sort_orders is optional, but, is expected to be specified for the :custom listing type.  
  #     This has to be a list of fields in the story object, along with ASC or DESC.
  #     Example: ["sort_rating DESC", "sort_date DESC", "reviews_count DESC"]
  #     Note that there are no performance guarantees -- the listing you request might indeed be very expensive.
  #     FIXME: How do we handle the case of someone abusing this to introduce performance bottlenecks deliberately, 
  #     and potentially causing a DoS attack?
  #
  # :filters is a hash that specifies what kind of stories to pick (details below)
  #   :exclude_stories         => list of story ids to exclude
  #   :use_date_window         => restrict story search to a date window
  #                               if this is a listing for a topic/subject, the window is set to 'topic_volume' days
  #                               if not, it is set to 1 day
  #   :ignore_story_status     => if true, story status is ignored in selecting stories
  #   :status                  => select by story status.
  #                               if omitted, only stories without 'hide' status are candidates for listing.
  #   :min_editorial_priority  => select stories with editorial priority value set to at least this number.  
  #                               if omitted, editorial priority is not considered.
  #   :min_submitter_level     => only stories submitted by members with a validation level > this value are picked.
  #   :topic                   => select by topic slug.
  #                               if specified, stories belonging to this topic (or subject) are candidates for listing.
  #                               if omitted, all stories are candidates
  #   :topic_ids               => multiple topics/subjects to fetch from
  #   :feed_id                 => feed from which to fetch stories
  #   :feed_ids                => multiple feeds to fetch from
  #   :story_type              => Story::NEWS / Story::OPINION
  #                               if specified, stories of the requested type are candidates
  #                               if omitted, all stories are candidates
  #   :story_rating_classes    => array of values from: Story::RATED, Story::UNRATED, Story::TRUSTED, Story::UNTRUSTED
  #   :sources                 => hash that specifies constraints on story sources as follows
  #     :ownership             => Source::MSM / Source::IND
  #                               if specified, stories belonging to the requested ownership type are candidates
  #                               if omitted, all stories are candidates
  #     :rating_class          => Source::UNRATED  / Source::RATED / Source::TRUSTED / Source::UNTRUSTED
  #     :ids                   => a list of ids
  #     :id                    => id of the source
  #                               if specified, will be used (rather than the slug)
  #     :slug                  => slug of the source
  #                               if specified, stories belonging to the requested source are candidates
  #                               if omitted, all stories are candidates
  #     :media_type            => media type of the source ("newspaper", "blog", "tv", "online", "wire", "magazine", "radio")
  #                               if specified, stories belonging to the source with the requested media type are candidates
  #                               if omitted, all stories are candidates
  #     :exclude_ids           => a list of database ids corresponding to sources that should not be considered
  #                               if specified, stories belonging to the specified sources are excluded
  #                               if omitted, all stories are candidates
  #                                 this option is used to ensure that certain listings (newsletters, homepage) 
  #                                 do not contain more than 1 story from the same source!
  #     :max_stories_per_source=> Max # of stories to show per source
  #                               the chosen stores are those that best satisfies all the earlier constraints (rating, story type, ownership, date, etc.)
  #                                 this option is used to ensure that certain listings (newsletters, homepage) 
  #                                 do not contain more than these number of stories from the same source!
  #                               IMPORTANT: This option is supported only for most_recent, most_trusted, and for_review
  #
  # :start_date, :end_date, :time_span are date values that specify a date range within which stories are to be picked for top-rated story listings
  #     where a time window is required (ex: when max_stories_per_source is in effect),
  #     if both :start_date & :end_date are specified, that date range is chosen (:start_date < :end_date)
  #     if :end_date is not specified, the current time is picked
  #     if :time_span is not specified, it is set to 1.day or # of days in the topic_volume field
  #     if :start_date is not specified, it is set to :end_date - :time_span
  #
  # :per_page specifies how many stories should be returned
  #
  # :page specifies what page of the story listing should be returned (with :per_page stories per page)
  #
  # :paginate asks us to set up pagination (even if false, note that we still need to respect the :per_page & :page values!)
  # 
  # :fill_story_window asks us to ensure we get the requested # of stories (only applicable for most_trusted story listings)
  #
  # :more_conditions is a conditions string that will be tagged on to the find conditions as is 
  #   for cases where the existing listing options dont do it!  But, beware, the string is copied verbatim!

  def self.list_stories(options = {})
      # clone options hash since we will modifying it!
    options = ObjectHelpers.deep_clone(options)

      # Sanitize the options hash
    StoryListingHelpers.sanitize_listing_options(options)

      # Set up clauses for requested filters
    filter_clauses = StoryListingHelpers.setup_all_filters(options[:filters])

      # Set up clauses for the requested listing type
    listing_clauses = StoryListingHelpers.setup_listing_type(options, filter_clauses[:requested_srcs])

      # Combine filter and listing type conditions
    conds = QueryHelpers.conditions_array([["stories.story_date IS NOT NULL", nil]] + filter_clauses[:conditions] + listing_clauses[:conditions])

    inner_joins = (filter_clauses[:joins] + listing_clauses[:joins]).uniq.inject("") { |js, j| js + " JOIN #{j}" }
    left_joins  = (filter_clauses[:left_joins] + listing_clauses[:left_joins]).uniq.inject("") { |js, j| js + " LEFT JOIN #{j}" }
    group_by    = (filter_clauses[:group_by] || []) + (listing_clauses[:group_by] || [])
    distinct    = filter_clauses[:distinct] || listing_clauses[:distinct]
    index_hint  = listing_clauses[:index_hint] || filter_clauses[:index_hint]

      # Set up the find options hash
    find_options = {
      :conditions => conds,
      :joins      => inner_joins + left_joins,
      :order      => listing_clauses[:order_by],
      :include    => options[:include],
      # SSS FIXME: Assumes that the caller wont be passing in a "distinct" constraint via options[:select]
      :select     => (distinct ? "DISTINCT " : "") + (options[:select] || "stories.*") 
    }

      # Set up pagination options
    paginate_options = {
      :per_page => options[:per_page] || 10,
      :page     => options[:page] || 1,
      :group    => !group_by.empty? ? group_by[0] : nil
    }

      # If we are using 'group by' to get distinct stories, use 'select distinct stories.id' while counting
      # because group by won't work for count queries!
    distinct_count = (paginate_options[:group] || distinct ? "distinct" : "")

    if options[:count_only] || options[:paginate]
        # NOTE: have to do a count to tally up :total_entries due to a bug in will_paginate! Should fix... (original comment by AF .. still true?)
      count_options = find_options.merge(:select => "#{distinct_count} stories.id")
      count_options.delete(:order)  # ordering not required for count queries
      num_available_stories = Story.count(count_options) 

        # If we only want a count, bail right here!
      return num_available_stories if options[:count_only]
    else
        # If we don't need pagination, don't bother with counting # of stories, simply set it to a high value!
      num_available_stories = 1000
    end

      # Pass the index hint through -- but set this AFTER the story count has been computed previously
    find_options[:from] = "#{quoted_table_name} USE INDEX(#{index_hint})" if index_hint

      # Extract source diversity filter option because it is cumbersome to use directly
    max_stories_per_source = options[:filters][:sources] && options[:filters][:sources][:max_stories_per_source]

      # If we need to ensure that the story listing has the requested # of stories, retry with longer time spans 
      # till we succeed or give up! (right now, only applicable for most_trusted listings)
      # If 'sd' is not defined, then, we have essentially looked in the entire db, and no need to retry anymore
    sd = options[:filters][:dw][:start_date]
    listing_type = options[:listing_type]
    if options[:all]
      return Story.find(:all, find_options.merge({:select => "#{find_options[:select]}"}))
    elsif (options[:fill_story_window] && [:most_trusted,:least_trusted].include?(listing_type) && sd && (num_available_stories < paginate_options[:per_page]))
      num_retries = options[:retry_counter]
      num_retries = num_retries ? 1+num_retries : 1

        # Retry with a longer and longer timespan to check for top stories!
        # after 6 retries, we would have gone as far back as 4+2+4+6+8+10+12 = 46 weeks <-- almost an year
      max_retries = 6
      if (num_retries <= max_retries)
        options[:start_date] = sd - (14*num_retries).days ## Minimize # of retries by increasing the time span by greater amounts
        options[:retry_counter] = num_retries
        logger.info "Must fill story window -- RETRYING #{listing_type} query with start-date of #{options[:start_date]}"
        return Story.list_stories(options)
      else
        logger.info "GIVING up after #{max_retries} retries!"
        return Story.paginate(find_options.merge(paginate_options).merge({:select => "#{find_options[:select]}", :total_entries => num_available_stories}))
      end
    elsif max_stories_per_source
        # We are implementing source diversity in ruby now ...
        # Select primary_source id field too since it is used to enforce source diversity
      fo = find_options.merge(paginate_options)
      fo[:select] += ", stories.primary_source_id" if fo[:select] != "stories.*" 
      return process_query_and_enforce_source_diversity(options, fo.merge({:select => "#{fo[:select]}", :total_entries => num_available_stories}), max_stories_per_source)
    elsif [:recent_reviews, :trusted_reviews].include?(listing_type)
        # Since a story can have multiple reviews, and since we are joining the reviews table,
        # the same story can appear multiple times in this listing.  Dedupe -- note that it is not
        # possible to use a distinct/group-by clause because of the "reviews.created_at DESC" ordering
        # is applied *after* the distinct stories are selected.  Because of this, a distinct/group-by
        # clause leads to the the story sort being based on the first review of a story, rather than
        # the latest review of a story
      fo = find_options.merge(paginate_options)
      return process_query_and_enforce_category_limits(options, fo.merge({:select => "#{fo[:select]}", :total_entries => num_available_stories}), {:category_obj => "story", :category_column => "id", :max_per_category => 1}) 
    else
        # All is well!  Note that we are using paginate options because we need to respect the :per_page & :group_by settings
      opts = find_options.merge(paginate_options).merge({:select => "#{find_options[:select]}", :total_entries => num_available_stories})
      return Story.paginate(opts)
    end
  end

  # SSS FIXME: This is  buggy -- doesn't work well in the presence of pagination since each run through this
  # method could fetch multiple pages (and hence page numbering will be off for pages 2 and later!) 
  def self.process_query_and_enforce_category_limits(orig_options, find_options, limits_opts)
    category          = limits_opts[:category_obj]
    column_to_exclude = limits_opts[:category_column]
    max_per_category  = limits_opts[:max_per_category] || 1

    # Fetch around 2x stories (unless we want just 1), and we'll hopefully find the stories we need!
    how_many = find_options[:per_page].to_i
    find_options[:per_page] = 2 * how_many if how_many > 1

    fetched_cat_objs   = orig_options[category.pluralize.to_sym][:exclude_ids] if orig_options[category.pluralize.to_sym]
    fetched_cat_objs ||= []
    no_excludes_yet    = fetched_cat_objs.empty?
    results            = []
    obj_id_hash        = fetched_cat_objs.inject({}) { |h, s| h[s] = max_per_category; h }

    num_attempts = 0
    while (num_attempts < 10) do
      num_attempts += 1

        # Fetch from db
      candidates = Story.paginate(find_options)

        # There is no hope of getting what we want
      break if candidates.empty?

        # Implement source-diversity filter
      member_points = {}
      candidates.each { |c|
        obj_id = c.send(column_to_exclude) 

          # Skip if we have processed the source
        next if obj_id_hash[obj_id] && (obj_id_hash[obj_id] >= max_per_category)

          # Add c to the result set
        results << c
        obj_id_hash[obj_id] ||= 0
        obj_id_hash[obj_id] += 1
        break if results.size == how_many
      }

        # Are we done?
      break if (results.size == how_many)

        # No!  Go back and fetch more stories!
      fetched_cat_objs = obj_id_hash.keys.reject { |k| obj_id_hash[k] < max_per_category }

        # Update the exclude-ids conditions so we don't fetch from those sources again!
      if !fetched_cat_objs.empty?
        conditions_string = find_options[:conditions][0]
        if no_excludes_yet
          find_options[:conditions][0] = conditions_string + " AND stories.#{column_to_exclude} NOT IN (#{fetched_cat_objs * ','})"
          no_excludes_yet = false
        else
          conditions_string.gsub!(/stories.#{column_to_exclude} NOT IN \(.*?\)/, "stories.#{column_to_exclude} NOT IN (#{fetched_cat_objs * ','})")
        end
      end

      # Next page!
      find_options[:page] ||= 1
      find_options[:page] = find_options[:page].to_i
      find_options[:page] += 1
    end

    if orig_options[:paginate]
      WillPaginate::Collection.create(find_options[:page], find_options[:per_page], find_options[:total_entries]) do |pager|
        pager.replace(results)
      end
    else
      results
    end
  end

  def self.process_query_and_enforce_source_diversity(orig_options, find_options, max_per_source=1)
    process_query_and_enforce_category_limits(orig_options, find_options, :category_obj => "source", :category_column => "primary_source_id", :max_per_category => max_per_source) 
  end

  def self.list_stories_with_associations(opts, reqd_associations = [:submitted_by_member, :sources, :feeds])
    if opts[:paginate]
      # Punting on this for now.  If we want pagination, dont bother with the 2-step process as below.
      # Use :include finder option for eager loading
      opts[:include] ||= reqd_associations
      Story.list_stories(opts)
    else
      # We are going to eager load associations since they are used in the most of the listings anyway
      # To avoid humongous queries, we first fetch story ids of story candidates, and load everything in one shot!
      opts[:select] = "stories.id"
      res = Story.list_stories(opts)
      if opts[:count_only]
        res
      else
        story_ids = res.map(&:id)
        if story_ids.blank?
          []
        else 
          # Make sure the original listing order is preserved
          h = {}
          Story.find(:all, :conditions => ["id in (?)", story_ids], :include => reqd_associations).each { |s| h[s.id] = s }
          story_ids.inject([]) { |l, sid| l << h[sid] }
        end
      end
    end
  end

  def self.normalize_opts_and_list_stories(local_site, opts = {})
    list_stories(StoryListingHelpers.normalize_options(local_site, opts))
  end

  def self.normalize_opts_and_list_stories_with_associations(local_site, opts, reqd_associations = [:submitted_by_member, :sources, :feeds])
    list_stories_with_associations(StoryListingHelpers.normalize_options(local_site, opts), reqd_associations)
  end

  # convenience method for queries
  def self.types_by_category(type_category)
    SiteConstants::ordered_hash("story_story_type").select{|key, val| val["category"] == type_category}.keys
  end

  def story_scope
    is_local.nil? ? "not_sure" : (is_local? ? StoryScope::LOCAL : StoryScope::NATIONAL)
  end

  def set_story_scope(scope, local_site=nil)
    if scope == "not_sure"
      self.is_local = (local_site && (local_site.default_story_scope == StoryScope::LOCAL)) || self.subject_tags.map(&:slug).include?("local")
    else
      self.is_local = (scope == StoryScope::LOCAL)
    end
  end

  def story_type_condensed
    story_type.nil? ? nil : (is_news ? "news" : (is_opinion ? "opinion" : "other"))
  end

  def story_type_expanded
    self.story_type
  end

  def is_news
    !Story.types_by_category("news").grep(story_type).empty?
  end

  def is_opinion
    !Story.types_by_category("opinion").grep(story_type).empty?
  end

  def primary_source
    Source.find(self.primary_source_id) if primary_source_id
  rescue Exception => e
    logger.error "Exception '#{e}' finding primary source for story #{self.id}"
    ps = sources.first
    update_attribute(:primary_source_id, ps.id) if ps
    ps
  end

  def group_reviews_count(group = nil)
    (group.nil? ? reviews_count : (group_rating(group, "reviews_count").to_i || 0))
  end

  def hide_rating(group = nil)
     # NOTE: whenever you modify this code, please make sure the corresponding checks
     # in get_rating_check_clause method is consistent
    group_reviews_count(group) < SocialNewsConfig["min_reviews_for_story_rating"]
  end

  def compute_sort_rating(group = nil)
    if group.nil?
      r = rating
      sr = primary_source ? primary_source.rating : 0
    else
      r  = group_rating(group)
      sr = primary_source ? primary_source.group_rating(group) : 0
    end

      # Here is how this works! This is a hack to get top-stories listing to work as desired without multiple db calls
      # MAX sort_rating value for unrated stories will be (5*100+5*10+5*1)/555 = 1.0
      # So, as long as most_recent listing doesn't include stories with < 1.0 rating,
      # this ensures that rated & unrated stories stay in separate blocks.
      # Additionally, unrated stories get sorted by editorial priority, primary source rating, and story rating -- in that order
    !hide_rating(group) ? r : ((self.editorial_priority || 1) * 100 + (sr || 1) * 10 + (r || 1) * 1) / 555
  end
  
  def saved_by?(member)
    Save.exists?(:story_id => self.id, :member_id => member.id) if member
  end

  def reviewed_by?(member)
    Review.exists?(:story_id => self.id, :member_id => member.id) if member
  end

  # Return the highest group of the last person to edit this story.
  #
  def edited_by_group
    edited_by_member.roles.last if edited_by_member
  end
  
  def swallow_dupe(dupe_id, member)
    # There seems to be a problem with the swallow_associations method under some versions of Mysql.
    # One suggestion would be to try and avoid using the swallow_assocation methods and instead use
    # built in rails methods of handling duplicates between records.
    # Here are two possible examples:
    #
    # self.review_ids = self.review_ids | dupe.review_ids
    #
    # ((self.source_ids | dupe.source_ids) - self.source_ids).each do |source|
    #   self.authorships.create(:source_id => source)
    # end
    
    dupe = Story.find_by_id(dupe_id)

      # Copy over the subtitle, as required
    self.subtitle = dupe.subtitle if (self.subtitle.blank?)

      ## Move the dupe reviews back to the dupe story ... editors will take care of that!
    num_nonpublic_transferred = 0
    swallow_associations(dupe, :reviews, false) { |r|
      begin
        # review can have different public status before/after transfer
        # so, lookup status before save!
        num_nonpublic_transferred += 1 if !r.is_public?
        r.story = self; r.save!
      rescue Exception => e # we hit a dupe review.  leave it in place then!
        logger.error "Exception '#{e}' moving review #{r.id} from #{dupe.id} to #{self.id} -- mostly like a duplicate.  So, we are retaining the review back with the 'dupe' story #{dupe.id}."
        r.story = dupe; r.save!
      end
    }

      # Update reviews_count if we have transferred non-public reviews
    if (num_nonpublic_transferred > 0)
      Story.update_reviews_count(self.id, -num_nonpublic_transferred) 
      Story.update_reviews_count(dupe.id, num_nonpublic_transferred)
    end

    # Don't swallow authorships! Trust that the one assigned matches the URL & is correct.
    
      ## Since we have an uniqueness constraint, this will not save dupes (and won't raise an exception because we are using save, not save!)
    swallow_associations(dupe, :saves)       { |s| s.story = self; s.save }

      ## Since we have a mysql uniqueness constraint, we have to catch duplicates.
#    swallow_associations(dupe, :story_clicks) { |c| 
#      if (!self.story_clicks.to_ary.find { |x| x.data == c.data })
#        c.story = self
#        c.save
#      end
#    }
      ## The ruby code above is very expensive -- if there are 50 clicks in self and dupe, the above code executes 150 sql commands!
    StoryClick.connection.update("update ignore story_clicks set story_id = #{self.id} where story_id = #{dupe.id}")

      ## Delete dupe from my list of related stories!
    StoryRelation.delete_all({ :story_id => self.id, :related_story_id => dupe.id })

      ## We don't have any uniqueness constraint, so, dont add duplicates
    swallow_associations(dupe, :story_relations) { |sr| sr.story = self; sr.save if !self.story_relations.to_ary.find { |x| x.equals(sr) }}

      ## Update story relation entries where dupe is a related story of somebody else!
    StoryRelation.connection.update("update story_relations set related_story_id=#{self.id} where related_story_id=#{dupe.id}")

      ## We have an uniqueness constraint on session, and "<<" will whine if we try to add without a dupe check
      ## SSS FIXME: Why are these ignored??
#    num_added = 0
#    swallow_associations(dupe, :page_views) { |p| 
#      p.viewable_id = self.id 
#      if !self.page_views.to_ary.find { |x| x.equals(p) }
#        self.page_views << p 
#        num_added += 1
#      end
#    }

      ## The ruby code above is very expensive -- if there are 100 pageviews in self and dupe, the above code executes 300 sql commands!
    npvs = PageView.connection.update("update ignore page_views set viewable_id = #{self.id} where viewable_id = #{dupe.id} and viewable_type = 'Story'")
    self.page_views_count += npvs
    dupe.page_views_count -= npvs

      ## No duplicate tags, mysql will whine because of an uniqueness constraint there!
      ## Without the clone, we get a frozen hash complaint
      ## IMPORTANT: Only check that the tag is same -- doesn't matter if the taggings were done by different members.
      ## Without this, the same tag can get duplicated on the merged story!
    swallow_associations(dupe, :taggings) { |t| self.taggings << t.clone if !self.taggings.to_ary.find { |x| x.has_same_tag(t) }}

      ## SSS FIXME: Yes, but, maybe provide the editor with an option?
      ## Delete 'dupe' from story_feeds -- cannot really move these to 'self' because the dupe story might have come from a different feed
    dupe.story_feeds.clear

      ## Update newsletter story entries!
    NewsletterStory.find(:all, :conditions => { :story_id => dupe.id }).each { |ns| ns.update_attribute(:story_id, self.id) }
    
    # store dupe's url with this story
    self.urls << StoryUrl.new(:url => dupe.url) unless self.url == dupe.url
    
      # FIXME: Ignore story_attributes for now ... in the future, we'll swallow dupe's attributes intelligently
      # If the stories being merged are stories from different sources, then, the attribute merging is not straightforward!
    
    # add handy note for editors
    merge_note = "NOTE: Story \"\##{dupe.id}\":/stories/#{dupe.id} was merged into story \"\##{self.id}\":/stories/#{self.id} by #{member.name} on #{Time.now}"
    self.edit_notes = self.edit_notes.nil? ? merge_note : self.edit_notes + "\n\n" + merge_note
    dupe.edit_notes = dupe.edit_notes.nil? ? merge_note : dupe.edit_notes + "\n\n" + merge_note

      # If the urls for self & dupe are the same, delete the dupe
    if (self.url == dupe.url)
      begin
        dupe.destroy
        ActivityEntry.destroy_all(:activity_id => dupe.id, :activity_type => 'Story') 
      rescue Exception => e
        logger.error "While trying to delete #{dupe.id} because it has same url as #{self.id}, encountered exception #{e}"
        dupe.update_attribute(:url, "DUPE_URL:#{dupe.id}:#{self.id}") # -- guaranteed to be unique!
      end
    else
        # Hide the dupe! (important: must occur before save call below for story_urls to validate)
      dupe.update_attribute(:status, HIDE)
    end

      # Reprocess ratings
    self.save_and_process_with_propagation
  end

  # for batch_autocomplete
  def authorships_attributes=(authorships_attributes)
    authorships.attributes_collection = authorships_attributes
  rescue ActiveRecord::StatementInvalid => e
    @found_duplicate_authorship_association = true
    logger.error "#{e}; Possible duplicate authorship attempted! Catching and ignoring exception."
  end

  def taggings_attributes=(taggings_attributes)
    taggings.attributes_collection = taggings_attributes
  rescue ActiveRecord::StatementInvalid => e
    @found_duplicate_tagging_association = true
    logger.error "#{e}; Possible duplicate tagging attempted! Catching and ignoring exception."
  end

  def urls_attributes=(urls_attributes)
    urls.attributes_collection = urls_attributes.reject{|ua| ua["url"].blank? and ua["should_destroy"]=="false" }
  end
  def story_relations_attributes=(story_relations_attributes)
      # If related_story_id is nil, save the story so that it gets an id
    story_relations_attributes.each {|sra| 
      if (sra["related_story_id"].blank? and (sra["url"] =~ %r|http://.+|) and sra["should_destroy"]=="false")
        begin
          s_url = sra["url"]

            # Check if the url is the url for a story page on our app!  
            # If so, instead of creating a new story, add a related link to the existing story on our app
            # there might be a port .. ignoring the port
          story_domain = NetHelpers.get_url_domain(s_url)
          if (story_domain =~ /#{APP_DEFAULT_URL_OPTIONS[:host]}/)
            story_id = s_url.gsub(%r|^.*/stories/|, "")
            rs = Story.find(story_id)
          else
            rs = Story.new
            rs.url = s_url
            rs.title = sra["title"]
            rs.status = PENDING
            rs.story_date = Time.now
            rs.editorial_priority = 3
            rs.content_type = "article"
            rs.submitted_by_id = sra["member_id"]
            rs.save!
          end
          sra["related_story_id"] = rs.id
        rescue Exception => e
          logger.error "Error saving related story #{url} for story #{self.id}: #{e}"
        end
      end
    }
    story_relations.attributes_collection = story_relations_attributes.reject{|sra| sra["related_story_id"].blank? and sra["should_destroy"]=="false" }
  end
  
  # for story edit form
  def review_attributes=(reviews_attributes)
    reviews_attributes.each do |review_id, review_attributes|
      reviews.find(review_id).update_attributes(review_attributes)
    end
  end
  
  # strip whitespace before and after the excerpt
  def excerpt=(str)
    str = str.strip
    write_attribute(:excerpt, str)
  end

  # any time the journalist_names are entered, check to see if they're all uppper case 
  # or all lower case. if so, convert to initial caps for each word
  # we're not doing this with all strings in case there's properly a mix of upper/lower,
  # as with McCain
  def journalist_names=(names)
    names = names.strip.gsub(" and ",", ").gsub(" AND ",", ").gsub(",,",",") # replace and with comma
    if names == names.upcase || names == names.downcase # all upper/lower case
        names = names.titleize
    end
    write_attribute(:journalist_names, names)
  end

  # virtual attribute to build date from form pull-downs
  def date_components=(date_components)
    begin
      self.story_date = Date.new(date_components[:year].to_i, date_components[:month].to_i, date_components[:day].to_i)
    rescue ArgumentError
      # errors.add(:story_date, " is invalid") # this error is superceded by the validates_presence_of one... so leave it out
    end
  end
  
  # Method to apply topics from the SAP/MdF using NT_BOT member.
  #
  def bot_topics=(bot_topic_tags)
    return if bot_topic_tags.blank?

    (bot_topic_tags - self.tags).each do |t| 
      begin 
        self.taggings << Tagging.new(:tag => t, :member_id => Member.nt_bot.id) 
      rescue Exception => e 
        logger.error "Exception #{e} adding tag #{t.name}; Ignoring it!" 
      end
    end
  end
  
  protected

  def init_activity_score
    m = self.submitted_by_member
    ActivityScore.boost_score(self, :member_submit, {:member => m, :url_ref => self.referrer_code}) if ![Member.nt_bot, Member.nt_anonymous].include?(m)
  end

  def set_cached_and_computed_values
    # FIXME: Seems wasteful to do a lot of this on every save
    if self.title
      # Get rid of all html tags from the title
      self.title.gsub!(/<.*?>/, '')
      self.title.strip!
    end
    self.excerpt.strip! if self.excerpt
    if self.journalist_names
      self.journalist_names.gsub!(%r{http://.*}i, '')
      self.journalist_names.strip! 
    end
    self.subtitle.strip! if self.subtitle
    self.story_type.strip! if self.story_type
    d = self.story_date
    if d.nil?
      d = Time.now
    else
      d = d.to_time if d.class == Date # Looks like edit forms store Date objects!
      d = Time.now if (d - Time.now.beginning_of_day) > 1.day  # No more way-in-the-future dates!
    end
    self.story_date = d

      # FIXME: Seems wasteful to do it on every save -- because it could load source and source media objects each time
      # but probably okay since stories are not edited/updated all that frequently after they are first submitted into the system
    self.sort_date = self.story_date.beginning_of_day
    if !authorships.blank?
      primary_source             = authorships.first.source
      self.stype_code            = (primary_source.ownership == Source::MSM) ? (is_news ? MSM_NEWS : MSM_OPINION) : (is_news ? IND_NEWS : IND_OPINION)
      self.primary_source_id     = primary_source.id
      self.primary_source_medium = primary_source.source_media.collect { |m| m.main ? m.medium : nil}.compact.first if primary_source.source_media
      self.sort_rating           = compute_sort_rating
    end
  end

  def update_subject_taggings_after_add(new_tagging)
    # We are trying to maintain the following canonical property:
    # If 't' is a topic tag on this story, and 't' belongs to subject 's', then the story also has the subject tag 's'
    new_tag = new_tagging.tag

    # 0. This is a not a topic or a subject.  Nothing to do
    return if !new_tag.is_topic_or_subject_tag?

    # 1. This is a tagging being added by the auto-tagger.  Nothing to do.
    nt_tagger_id = Member.nt_tagger.id
    return if new_tagging.member_id == nt_tagger_id

    # 2. This is a subject
    #
    # Since we constrain subjects to be identical across all national & local sites, it is sufficient
    # to check fetch subjects on the national site.
    #
    # Nothing to do except remove any stale/duplicate subject tags
    if new_tag.is_subject_tag?
      new_s = Subject.tagged_subject(new_tag)
      if new_s.nil?
        logger.error "Nil subject for story #{self.id} and new tag #{new_tag}"
      else
        # Remove identical nt-tagger subject tags -- both from the db as well as from the 'taggings' in-memory array!
        Tagging.delete_all({:tag_id => new_tag.id, :member_id => nt_tagger_id, :taggable_id => self.id, :taggable_type => "Story" })
        self.taggings.reject! { |t| (t.tag_id == new_tag.id) && (t.member_id == nt_tagger_id) }

        # SSS FIXME: Is this call required?
        remove_stale_subject_tags
      end

      return
    end

    # 3: This is a topic: fetch subject tags across all sites
    #
    # Since we constrain same-name topics across sites to belong to the same set of subjects on all those sites,
    # it is sufficient to get any topic that uses this tag.

    # First, the national site, then the local site
    new_t = Topic.topics_only.find(:first, :conditions => {:tag_id => new_tag.id})
    if new_t.nil?
      logger.error "Nil topic for story #{self.id} and new tag #{new_tag}"
      return
    end
    new_subj_tags = new_t.subjects.map(&:tag) - self.subject_tags
    new_subj_tags.each { |s| 
      next if s.nil?  # But why would this happen??

      # build taggings that commits to the db or stay in-memory depending on whether 'new_tagging' is in the db or not.
      if new_tagging.new_record?
        self.taggings.build(:tag_id => s.id, :member_id => nt_tagger_id)
      else
        self.taggings << Tagging.new(:tag_id => s.id, :member_id => nt_tagger_id)
      end
    }

    # SSS FIXME: Is this call required?
    # Remove any stale/duplicate subject tags that are no longer required after this auto-tagging
    remove_stale_subject_tags
  end

  def update_subject_taggings_after_delete(old_tagging)
    # Do not invoke the callback if we are deleting a nt_tagger tag or a non-topic or subject tag
    old_tag = old_tagging.tag
    nt_tagger_id = Member.nt_tagger.id
    return if !old_tag.is_topic_or_subject_tag? || old_tagging.member_id == nt_tagger_id

    if old_tag.is_topic_tag?
      remove_stale_subject_tags 
    else
      # Check if we need to add a new auto-tag subject tags to replace the one being removed
      s_on_all_sites = Subject.find(:all, :conditions => {:tag_id => old_tag.id}, :select => "id").map(&:id)

      # Find a topic tag that belongs to the removed subject on any site
      s_topic_tag = Topic.find(:first, 
                               :joins      => "JOIN topic_relations ON topic_id = topics.id",
                               :conditions => { "topics.type" => nil,
                                                "topics.tag_id" => self.topic_tags.map(&:id),
                                                "topic_relations.related_topic_id" => s_on_all_sites })

      # If the story still has topics that belong to the removed subject, we'll add an auto-inferred subject
      self.taggings << Tagging.new(:tag_id => old_tag.id, :member_id => nt_tagger_id) if !s_topic_tag.nil?
    end
  end

  private

  def remove_stale_subject_tags
    # Remove any stale subject taggings that are no longer valid 
    nt_tagger = Member.nt_tagger

    # Find the new set of (explicit and implicitly inferred) member subject tags
    member_subject_tags = self.taggings.collect { |t|
      begin
        # Since we constrain same-name topics across sites to belong to the same set of subjects on all those sites,
        # it is sufficient if we hit on a single site.  So, we'll try national site first, and the local site next.
        tag = t.tag
        if (tag.tag_type == Tag::TOPIC)
          (Topic.topics_only.find(:first, :conditions => {:tag_id => tag.id})).subjects.map(&:tag)
        elsif (tag.tag_type == Tag::SUBJECT) && (t.member != nt_tagger)
          tag
        end
      rescue Exception => e
        logger.error "Exception #{e} while inspecting tagging #{t.inspect} for story #{self.id}"
      end
    }.compact.flatten.uniq

    # Remove any auto-tagger subject tags that no longer belong to the new set -- both from the db as well as from the 'taggings' in-memory array!
    stale_tag_ids = (self.subject_tags - member_subject_tags).map(&:id)
    Tagging.delete_all({:tag_id => stale_tag_ids, :member_id => nt_tagger.id, :taggable_id => self.id, :taggable_type => "Story" })
    taggings.reject! { |t| stale_tag_ids.include?(t.tag_id) && (t.member_id == nt_tagger.id) }
  end

  def swallow_associations(model, assocs, destroy = true)
    cloned_assocs = model.send(assocs).clone
    cloned_assocs.each { |a| yield a }
    model.send(assocs, true).each{ |x| x.destroy } if destroy
  end
  
  # ugh ActiveRecord doesn't do the right thing for SQL "NOT IN" statements... must do by hand
  # OK to circumvent sanitization here; not worried about sql injection in these cases.
  def self.array_to_sql(array, quote_items=true)
    "(" + array.collect{ |item| quote_items ? "'#{item}'" : "#{item}" }.join(",") + ")"
  end
end
