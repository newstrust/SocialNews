class Source < ActiveRecord::Base
    ## Source ownership types
  MSM       = "msm"
  IND       = "ind"
  OWNERSHIP = { "" => "", MSM => "Mainstream", IND => "Independent" }

    ## Source rating types
  UNRATED   = "unrated"
  UNTRUSTED = "untrusted"
  LISTED    = "listed"
  RATED     = "rated"
  TRUSTED   = "trusted"

    ## Source status
  PENDING   = "pending"
  HIDE      = "hide"
  LIST      = "list"
  FEATURE   = "feature"

  @@status_choices = %w(pending hide list feature)
  cattr_reader :status_choices

  acts_as_processable
  
  attr_protected :rating
  
  has_friendly_id :slug
  has_many :comments, :as => :commentable, :dependent => :destroy
  has_many :authorships
  has_many :stories, :through => :authorships
  has_many :source_media, :extend => BatchAssociationExtension
  has_many :source_reviews
  has_many :feeds, :foreign_key => :source_profile_id
  has_one :image, :as => :imageable, :dependent => :destroy
  belongs_to :edited_by_member, :class_name => "Member"

  # SSS FIXME: With the addition of source_stats, can get rid of local_sites association
  has_and_belongs_to_many :local_sites
  has_many :source_stats, :dependent => :delete_all, :class_name => 'SourceStats'

  acts_as_hostable

  has_many :followed_items, :as => :followable
  has_many :followers, :through => :followed_items
  has_many :source_relations, :extend => BatchAssociationExtension, :dependent => :delete_all
  has_many :related_sources, :through => :source_relations, :source => :related_source
  has_many :affiliations, :dependent => :delete_all
  has_eav_behavior :fields => ["source_names_other",
                               "online_access", "source_audience_size",
                               "source_text", "description_link_address",
                               "description_link_media_type",
                               "description_link_source_name",
                               "journalist_names_featured",
                               "source_managers", "source_owners", "source_organization_type",
                               "source_address1", "source_address2", "source_city",
                               "source_country", "source_state", "source_zip", "source_scope",
                               "source_language", "source_other_tags",
                               "source_duplicate_links", "source_web_contact_address",
                               "source_public_email_address", "source_public_phone_number",
                               "source_representative_name",
                               "source_representative_member_check",
                               "source_representative_email", "source_representative_phone",
                               "discuss_source_status",
                               "contact_source_status", "source_logo_status",
                               "political_viewpoint", "source_edit_notes",
                               "edit_form_ID",

                               # TODO: need a way to store stories ABOUT a source in the stories table, not here!
                               "related_story_1_title", "related_story_1_url", "related_story_1_source_name",
                               "related_story_2_title", "related_story_2_url", "related_story_2_source_name"]

  acts_as_textiled :discussion_description
  named_scope :commentable, :conditions => { :allow_comments => true }

  attr_accessor :local_site_list
  after_save :update_local_sites

  # If you change ownership of the source, stype_code of all this sources stories would have to change as well.
  after_save :update_story_types, :if => :source_ownership_changed

    # SSS: UGH! cannot have this constraint because of null slugs -- rails barfs on those as being non-unique
    # Prevent slugs from being reused across sources!
  # validates_uniqueness_of :slug

  define_index do
    indexes :name, :sortable => true
    indexes :slug
    indexes :domain
    indexes :url
    #indexes source_attributes.name, :as => :source_attributes_name
    #indexes source_attributes.value,:as => :source_attributes_value
    
    has updated_at, :as => :sort_field
  end

  def favicon
    return @favicon if @favicon

    source_favicon_dir = "/images/source_favicons" # SSS FIXME: hardcoded!
    slug = self.slug
    if slug
      path = "#{source_favicon_dir}/#{slug}.png"
      @favicon = File.exists?("#{RAILS_ROOT}/public/#{path}") ? path : ""
    else
      @favicon = ""
    end
  end
  
  # the medium is tedium!!!
  def primary_medium
    primary_source_medium = source_media.select{ |sm| sm.main }.compact.first
    primary_source_medium.medium if primary_source_medium
  end
  
  # gives you an alphabatized list like "blog, online"
  def media_list
    source_media.sort{|x,y| x.medium <=> y.medium }.map{ |x| x.medium }.join(', ')
  end
  
  # TODO: use acts_as_network or something here... for now, do it the cheap way
  def related_sources_reciprocal
    (related_sources +
      SourceRelation.find(:all, :conditions => {:related_source_id => id}).map(&:source)
      ).uniq.compact
  end
  
  def source_media_attributes=(source_media_attributes)
    source_media.attributes_collection = source_media_attributes
  end
    
  def is_public?
    !["hide", "pending"].include?(self.status)
  end

  def active_feeds
    @active_feeds ||= feeds.reject { |f| f.auto_fetch == false }
  end

  # NOTE: modify story_listing_helpers.rb/get_rating_check_clause whenever you modify this method
  # FIXME: Doesn't work for groups!
  def hide_rating(local_site=nil)
    rating_stats = local_site ? self.source_stats.find_by_local_site_id(local_site.id) : self
    return (rating_stats.reviewed_stories_count < SocialNewsConfig["min_stories_for_source_rating"] or rating_stats.story_reviews_count < SocialNewsConfig["min_reviews_for_source_rating"] or rating_stats.rating == 0.0)
  end

  def format_for_widget
    if (self.status == PENDING)
      return {
        "id"        => self.slug,
        "name"      => self.name,
        "framebuster" => self.is_framebuster,
        "type"      => "",
        "ownership" => "",
            ## IMPORTANT: when zero, set it as "0.0", not as 0.0 so that this value is treated as non-null
        "rating"    => "0.0"
      }
    else
      return {
        "id"        => self.slug,
        "name"      => self.name,
        "framebuster" => self.is_framebuster,
        "type"      => primary_medium,
        "ownership" => (self.ownership == "mainstream") ? MSM : IND,
        "is_public" => self.is_public?,
        "rating"    => sprintf("%0.1f", self.rating)
      }
    end
  end

  def source_review_by_member(local_site, member)
    SourceReview.find_or_initialize_by_local_site_id_and_source_id_and_member_id(local_site ? local_site.id : nil, self.id, member ? member.id : nil)
  end

  def top_authors(local_site_id=nil)
    local_site = LocalSite.find(local_site_id) if local_site_id

    joins = ""
    conds = "stories.primary_source_id = #{self.id} and stories.status IN ('#{Story::LIST}', '#{Story::FEATURE}')"

    if !local_site.nil?
      joins += " join taggings t2 on t2.taggable_id=stories.id and t2.taggable_type='Story' and t2.tag_id=#{local_site.constraint_id}"
    end

    # collect names and process names
    h = {}
    Story.count(:joins => joins, :conditions => conds, :group => "journalist_names").each { |j, c|
      if j
        j.gsub!("By ", '')
        j.gsub!(/\s*,\s*/, ',')
        j.gsub!(/\s*;\s*/, ';')
        j.gsub!(/\./, '')
        j.gsub!(/\(.*\)/, '')
        j.gsub!(/\s(and)\s/, ',')
        j.split(',').collect{ |t| t.split(';') }.flatten.compact.each { |n|
          n.downcase!
          h[n] = (h[n] || 0) + c
        }
      end
    }

    # Sort by decreasing order of frequency, pick the top 100 & skip the rest (who care for more than this anyway?)
    h.sort {|a,b| b[1]<=>a[1] }[0..100]
  end

  def top_formats(local_site_id=nil)
    local_site = LocalSite.find(local_site_id) if local_site_id

    joins = ""
    conds = "stories.primary_source_id = #{self.id} and stories.status IN ('#{Story::LIST}', '#{Story::FEATURE}')"

    if !local_site.nil?
      joins += " join taggings t2 on t2.taggable_id=stories.id and t2.taggable_type='Story' and t2.tag_id=#{local_site.constraint_id}"
    end

    # sort by decreasing order of frequency
    Story.count(:joins => joins, :conditions => conds, :group => "stories.story_type").reject { |r| r[0].blank? }.sort { |a, b| b[1] <=> a[1] }
  end

  def topic_expertise(local_site_id=nil)
    local_site = LocalSite.find(local_site_id) if local_site_id

    h = {}
    srs = SourceReview.find(:all, 
                            :select => "expertise_topic_ids", 
                            :conditions => ["source_id=#{self.id} AND expertise_topic_ids IS NOT NULL AND local_site_id#{local_site ? "=#{local_site.id}" : " IS NULL"}"])
    srs.each { |sr|
      sr.expertise_topic_ids.split(",").each { |id| h[id] = (h[id] || 0) + 1 }
    }

    # Sort by decreasing order of frequency, pick the top 20
    h.sort {|a,b| b[1]<=>a[1] }[0..20]
  end

  def top_topics(local_site_id=nil)
    local_site = LocalSite.find(local_site_id) if local_site_id

    joins = "join taggings on stories.id = taggable_id and taggable_type='Story'" + \
            "join topics on topics.tag_id=taggings.tag_id"
    conds = "stories.primary_source_id = #{self.id} and stories.status IN ('#{Story::LIST}', '#{Story::FEATURE}')"

    if local_site.nil?
      conds += "and topics.local_site_id is null"
    else
      joins += " join taggings t2 on t2.taggable_id=stories.id and t2.taggable_type='Story' and t2.tag_id=#{local_site.constraint_id}"
      conds += " and topics.local_site_id=#{local_site.id}"
    end

    # Sort by decreasing order of frequency
    Story.count(:joins => joins, :conditions => conds, :group => "topics.id").sort { |a,b| b[1] <=> a[1] }
  end

  def update_sort_ratings_for_unrated_stories
    rating_factor = self.rating ? 10*self.rating : 0
    begin
      Story.update_all("sort_rating = (editorial_priority*100 + #{rating_factor} + rating)/555", "#{Story.get_rating_check_clause(Story::UNRATED)} AND primary_source_id = #{self.id}")
# FIXME!
#      GroupStory.update_all("sort_rating = (editorial_priority*100 + #{rating_factor} + rating)/555", )
    rescue Exception => e
      logger.error "Exception trying update sort ratings for source #{self.name} and id #{self.id}: #{e}"
    end
  end

  # for batch_autocomplete
  def source_relations_attributes=(source_relations_attributes)
    source_relations.attributes_collection = source_relations_attributes
  end

  def average_rating_by_member(member)
    Review.average(:rating, :joins => "JOIN authorships ON reviews.story_id=authorships.story_id",
      :conditions => {'reviews.member_id' => member.id, 'authorships.source_id' => self.id}) if member
  end

  def public_stories_count(days_limit=nil)
    conditions = ["authorships.source_id = ? AND #{Story.is_public_sql_clause}", self.id]
    if !days_limit.nil?
      conditions[0] += " AND stories.created_at >= ?"
      conditions << (Time.now - days_limit.days)
    end
    Story.count(:all, :joins => "JOIN authorships ON stories.id = authorships.story_id", :conditions => conditions)
  end

  def public_story_reviews_count(days_limit=nil)
    if days_limit.nil?
      story_reviews_count
    else
      Review.count(:all, 
                  :joins => "JOIN stories ON reviews.story_id=stories.id JOIN authorships ON stories.id = authorships.story_id",
                  :conditions => ["authorships.source_id = ? AND #{Story.is_public_sql_clause} AND reviews.status IN ('list','feature') AND stories.created_at >= ?", self.id, Time.now - days_limit.days])
    end
  end

  # group is not used, but it is passed in by ProcessJob, so we need to include it in the argument list
  def update_review_stats(group=nil)
    self.source_reviews_count, self.review_rating = SourceStats.source_review_stats(self.id)
    save!
  end

  def destroy
    if (self.authorships.empty?)
      super
    else
      return false
    end
  end

  def swallow_dupe(dupe)
      # Update primary_source_id of stories pointing to the dupe source
    Story.update_all({"primary_source_id" => self.id}, "primary_source_id = #{dupe.id}")

      # Migrate all of dupe's stories to me (only those that won't result in duplicates)
    ((self.story_ids | dupe.story_ids) - self.story_ids).each { |sid| self.authorships << Authorship.new(:story_id => sid) }

      # Destroy all of dupe's authorships
    dupe.authorships.each { |a| a.destroy }

      # Migrate all member affiliations from the old source to the new! 
    Affiliation.update_all("source_id = #{self.id}", "source_id = #{dupe.id}")

      # No more story reviews with dupe
    dupe.story_reviews_count = 0
    dupe.rating = 0

      # Migrate all of dupe's source reviews to me!
    num_new_reviews = 0
    dupe.source_reviews.each { |dsr|
      begin
        dsr.source = self
        dsr.save!
        num_new_reviews += 1
      rescue Exception => e # we hit a dupe review.  Leave it in place then!
        logger.error "Exception moving source review #{dsr.id} from source #{dupe.id} to #{self.id}: #{e} ... mostly like because member #{dsr.member.name} has reviewed both sources.  So, we are retaining this source review back with the 'dupe' story."
        dsr.source = dupe 
        dsr.save!
      end
    }

      # Update source_reviews_count -- this won't get automatically updated
    self.source_reviews_count += num_new_reviews
    dupe.source_reviews_count -= num_new_reviews

      # Delete the duplicate source (reload so that the record has fresh info about authorships -- otherwise destroy will fail!)
    dupe.reload.destroy

      # Reprocess ratings -- this will also update self.story_reviews_count
    self.save_and_process_with_propagation
  end

  def swallow_dupes(dupes)
    dupes.each { |d| swallow_dupe(d) }
  end

  def before_save
    # friendly_id will happly save an empty slug which is wrong. 
    # We need to ensure blanks slugs are set to nil before saving.
    self.slug = nil if self.slug && self.slug.empty?
  end

  def update_local_sites
    if LocalSite.count > 0 && self.source_stats.blank?
      # add source stats objects if necessary
      LocalSite.find(:all).each { |ls| self.source_stats << SourceStats.create(:local_site_id => ls.id) }

      # update stats if we are going public and source status changed
      if status_changed? && is_public?
        self.source_stats.each { |ss|
          ss.update_review_stats # FIXME: shouldn't this get folded into the update_stats method below?
          ss.update_stats
        }
      end
    end

    self.local_sites = LocalSite.find(local_site_list.keys) if !local_site_list.nil?
  end

  RATED_STORY_THRESHOLDS = {
    :overall     => { :msm => 50, :ind => 50, :msm_news => 20, :ind_news => 10, :msm_opinion => 20, :ind_opinion => 20 },
    :subjects    => { :msm => 20, :ind => 10, :msm_news => 10, :ind_news =>  5, :msm_opinion => 10, :ind_opinion =>  5 },
    :high_volume => { :msm => 10, :ind =>  6, :msm_news =>  5, :ind_news =>  3, :msm_opinion =>  5, :ind_opinion =>  3 },
    :low_volume  => { :msm =>  6, :ind =>  4, :msm_news =>  3, :ind_news =>  2, :msm_opinion =>  3, :ind_opinion =>  2 },
    :publication => { :all =>  5, :msm => 10, :ind => 5 }
  }

  # If you have any hardcoded sources you want to ignore from source listings, here is where you hardcode it.
  # This could potentially come from the db (via admin settings), but this will do for now
  # If you have nothing to ignore, return [-1].  returning [] will break sql queries that use this
  def self.sources_to_ignore
    # Source.find_all_by_slug(["bad_source_1", "bad_source_2"]).map(&:id)
    [-1]
  end

  def self.top_sources_for_subject(subject, num_sources=5)
    top_sources = {}
    time_threshold = Time.now - 365.days
    rated_story_thresholds = RATED_STORY_THRESHOLDS[:subjects]
    stmt = "select * from (select id, name, count(*) as num_stories, round(avg(story_rating),1) as avg_source_rating from (select sources.id, sources.name, round(avg(stories.rating),1) as story_rating from sources,authorships,stories,taggings where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.stype_code=? and stories.created_at >= ? and taggings.taggable_id=stories.id and taggings.tag_id=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id, stories.id) as tmp group by id) as tmp2 where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
    [:msm_news, :msm_opinion, :ind_news, :ind_opinion].each { |stype|
      query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], eval("Story::#{stype.to_s.upcase}"), time_threshold, subject.tag_id, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[stype]*3.3).round, sources_to_ignore, rated_story_thresholds[stype], num_sources ])
      top_sources[stype] = Source.connection.select_all(query)
    }
    stmt = "select * from (select id, name, count(*) as num_stories, round(avg(story_rating),1) as avg_source_rating from (select sources.id, sources.name, round(avg(stories.rating),1) as story_rating from sources,authorships,stories,taggings where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.created_at >= ? and taggings.taggable_id=stories.id and taggings.tag_id=? and sources.ownership=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id, stories.id) as tmp group by id) as tmp2 where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
    [:msm, :ind].each { |ownership|
      query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], time_threshold, subject.tag_id, ownership.to_s, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[ownership]*3.3).round, sources_to_ignore, rated_story_thresholds[ownership], num_sources ])
      top_sources[ownership] = Source.connection.select_all(query)
    }

    return top_sources
  end

  def self.top_sources_for_topic(topic, num_sources=5)
    top_sources = {}
    time_threshold = Time.now - 365.days
    rated_story_thresholds = RATED_STORY_THRESHOLDS[topic.is_high_volume? ? :high_volume : :low_volume]

    stmt = "select id,name,num_stories,avg_source_rating from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories,taggings where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.stype_code=? and stories.created_at >= ? and taggings.taggable_id=stories.id and taggings.tag_id=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
    [:msm_news, :msm_opinion, :ind_news, :ind_opinion].each { |stype|
      query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], eval("Story::#{stype.to_s.upcase}"), time_threshold, topic.tag_id, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[stype]*3.3).round, sources_to_ignore, rated_story_thresholds[stype], num_sources ])
      top_sources[stype] = Source.connection.select_all(query)
    }

    stmt = "select id,name,num_stories,avg_source_rating from (select sources.id, sources.name, count(*) as num_stories, round(avg(stories.rating),1) as avg_source_rating from sources,authorships,stories,taggings where authorships.source_id=sources.id and authorships.story_id=stories.id and stories.status in (?) and stories.reviews_count >= ? and stories.created_at >= ? and taggings.taggable_id=stories.id and taggings.tag_id=? and sources.ownership=? and sources.status in (?) and sources.story_reviews_count > ? and sources.id NOT in (?) group by sources.id) as tmp where num_stories >= ? order by avg_source_rating desc, num_stories desc limit ?"
    [:msm, :ind].each { |ownership|
      query = Source.send("sanitize_sql_array", [ stmt, ["#{Story::LIST}", "#{Story::FEATURE}"], SocialNewsConfig["min_reviews_for_story_rating"], time_threshold, topic.tag_id, ownership.to_s, ["#{Source::LIST}", "#{Source::FEATURE}"], (rated_story_thresholds[ownership]*3.3).round, sources_to_ignore, rated_story_thresholds[ownership], num_sources ])
      top_sources[ownership] = Source.connection.select_all(query)
    }
    return top_sources
  end

  class << self
    # used on source listing page
    def top_rated_by_medium(key, find_options={})

      conditions = find_options[:conditions] || [""]
      conditions[0] += " AND " unless conditions[0].blank?

      # Basic conditions: at least X rating and listed source
      conditions[0] += " sources.status in ('list','feature')"
      conditions[0] += " AND sources.rating >= ?"
      conditions << SocialNewsConfig["min_trusted_source_rating"]

      conditions[0] += " AND sources.id NOT IN(?)"
      conditions << sources_to_ignore

      # Ignore local scope sources if we have been asked to
      no_local_scope = find_options.delete(:no_local_scope)
      if no_local_scope
        find_options[:joins] ||= ""
        find_options[:joins] += " LEFT JOIN source_attributes ON source_attributes.source_id=sources.id AND source_attributes.name='source_scope'"
        conditions[0] += " AND (source_attributes.value IS NULL OR source_attributes.value NOT IN ('local', 'state', 'regional'))"
      end

      # We want sources with at least X rated stories from last 365 days OR at least Y reviews from last 365 days
      cutoff_date = Time.now - 365.days
      listing_constants = source_medium_info(key)["listing_options"]
      conditions[0] += " AND (((SELECT COUNT(*) FROM stories JOIN authorships ON authorships.story_id=stories.id WHERE authorships.source_id=sources.id AND stories.status IN ('list','feature') AND stories.created_at >= ? AND stories.reviews_count >= ?) > ?) OR ((SELECT COUNT(*) FROM stories JOIN authorships ON stories.id=authorships.story_id JOIN reviews ON reviews.story_id=stories.id WHERE authorships.source_id=sources.id AND stories.status IN ('list','feature') AND stories.created_at >= ? AND reviews.status IN ('list','feature')) > ?))"
      conditions += [cutoff_date, SocialNewsConfig["min_reviews_for_story_rating"], listing_constants["min_stories"], cutoff_date, listing_constants["min_story_reviews"]]

      find_options[:conditions] = conditions
      find_options[:order] = "sources.rating DESC"
      list_by_medium(key, find_options)
    end

    def list_visible_by_medium(key, find_options={})
      conditions = find_options[:conditions] || [""]
      conditions[0] += " AND " unless conditions[0].blank?
      conditions[0] += " sources.status in ('list','feature')"

      # We want sources with at least 1 submitted story from last 365 days
      cutoff_date = Time.now - 365.days
      listing_constants = source_medium_info(key)["listing_options"]
      conditions[0] += " AND ((SELECT COUNT(*) FROM authorships JOIN stories ON authorships.story_id=stories.id WHERE authorships.source_id=sources.id AND stories.status IN ('list','feature') AND stories.created_at >= ?) > 1)"
      conditions += [cutoff_date]

      find_options[:from] = "sources USE INDEX(index_sources_on_rating_and_status)" 
      find_options[:conditions] = conditions
      list_by_medium(key, find_options)
    end

    def list_all_by_medium(key, find_options={})
      list_by_medium(key, find_options.merge(:conditions => ["sources.status IN ('hide', 'list', 'feature')"]))
    end
    
    def list_by_medium(key, find_options)
      find_options[:order] ||= "sources.name ASC"
      find_options[:joins] ||= ""
      find_options[:joins] += " JOIN source_media ON sources.id=source_media.source_id"
      find_options[:conditions] ||= [""]
      find_options[:conditions][0] += " AND " unless find_options[:conditions][0].blank?
      find_options[:conditions][0] += "source_media.medium = ? AND source_media.main = 1"
      find_options[:conditions] << key
      Source.find(:all, find_options)
    end

    def validate_ownership(ownership)
      return ownership if SiteConstants::ordered_hash("source_ownership")[ownership]
    end

    def each_source_medium
      SiteConstants::ordered_hash("source_media").reject{|key, val| key=="other"}.each do |key, medium|
        yield(key, medium)
      end
    end

    def source_medium_info(key)
      SiteConstants::ordered_hash("source_media")[key]
    end

    def source_medium_name(key)
      source_medium_info(key)["name"]
    end

      ## FIXME: Maybe move this code to initialize and then call Source.new(blah, blah) rather than Source.build_new_source(blah, blah)?
      ## Check whether there is a rails gotcha about initializers before doing this change
    def build_new_source(name, domain=nil)
        # Try to see if there is an existing source object with an identical name but a null domain
        # If so, use that and update the info for that source object
      source = Source.find(:first, :conditions => ["domain IS NULL AND name = ?", name])
      if source.nil?
          ## Build a new source object!
        source            = Source.new
        source.name       = name
        source.section    = nil
        source.ownership  = IND
        source.status     = PENDING
        source.source_media << SourceMedium.new(:medium => SourceMedium::OTHER, :main => true)
        source.created_at = Time.now
        source.updated_at = Time.now
      end

      if domain
        source.domain = domain
        source.slug   = domain.gsub(/\./, '_')
      end

      return source
    end

    # for batch_autocomplete
    def find_or_initialize_pending_source_by_name(name)
      Source.find_by_name(name) || build_new_source(name)
    end
  end

  protected

  def source_ownership_changed
    self.ownership_changed?
  end

  def update_story_types
    # Goes without saying ... keep up with constants in app/models/story.rb
    change = self.ownership == IND ? (Story::IND_NEWS - Story::MSM_NEWS) : (Story::MSM_NEWS - Story::IND_NEWS)
    Story.update_all("stype_code = stype_code + #{change}", "primary_source_id = #{self.id}")
  end
end
