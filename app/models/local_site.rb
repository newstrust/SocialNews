class LocalSite < ActiveRecord::Base
  acts_as_hostable

  has_many   :layout_settings, :dependent => :destroy
  belongs_to :invitation
  belongs_to :constraint, :polymorphic => true  # Right now, only tags can be constraints.  Later, maybe other things.
  has_many   :newsletters

  has_and_belongs_to_many :sources

  after_create :instantiate_taxonomy
  after_create :initialize_sources

  validates_presence_of :name
  validates_presence_of :slug
  validates_presence_of :subdomain

  PRIMARY_DOMAIN = APP_DEFAULT_URL_OPTIONS[:host]

  # Subject listings for the home page
  NATIONAL_SITE_SUBJECT_SLUGS = SocialNewsConfig["app"]["main_subject_slugs"]

  def self.national_site
    "http://#{PRIMARY_DOMAIN}"
  end

  def self.home_page(local_site)
    local_site.nil? ? national_site : local_site.home_page
  end
  
  def self.primary_site_subjects(local_site)
    (local_site.nil? ? NATIONAL_SITE_SUBJECT_SLUGS : local_site.landing_page_subject_slugs).collect { |slug| Subject.find_subject(slug, local_site) }
  end

  def self.max_stories_per_source(local_site)
    local_site ? (local_site.max_stories_per_source.to_i == 0 ? nil : local_site.max_stories_per_source) : 1
  end

  def self.default_date_window_size(local_site)
    local_site.nil? ? 7 : 10
  end

  def self.date_window_size_for_topic_listing(local_site, topic)
    return default_date_window_size(local_site) if topic.nil?

    dw = topic.topic_volume
    if local_site
      dw *= 4
      if dw < 30
        dw = (dw/7.0).round * 7
      elsif dw < 60
        dw = (dw/15.0).round * 15
      elsif dw < 180
        dw = (dw/30.0).round * 30
      else
        dw = 365
      end
    end
    dw
  end

  # SSS FIXME: Why a hardcoded timespan for least trusted (as opposed to using the topic volume settings?)
  # Because most often, there aren't enough least trusted stories to pick
  def self.least_trusted_date_window_size(local_site)
    (local_site ? 2 : 1) * Story::LEAST_TRUSTED_TIMESPAN
  end

  def self.nt_twitter_account(local_site)
    local_site.nil? ? SocialNewsConfig["app"]["twitter"] : "" # SSS FIXME: this twitter account should come from the database
  end

  def self.newsletter_frequencies(local_site)
    # SSS FIXME: Hardcoded to empty newsletters for local sites -- this should come from the database
    (local_site.nil? ? [Newsletter::DAILY, Newsletter::WEEKLY] : []) - Newsletter::DISABLED_NEWSLETTERS
  end

  def self.newsletter_site_logo(local_site)
    # SSS FIXME: Hardcoded for local sites -- this should come from the database
    local_site.nil? ? SocialNewsConfig["app"]["logo_path"] : "images/logos/local_sites/#{local_site.slug}/#{SocialNewsConfig["app"]["slug"]}-horizontal-logo-180px.gif"
  end

  ## Cached db calls ==> whenever a new local site is added, mongrels would have to be restarted!
  ## In reality, very very very rare!
  @@first_local_site = nil
  def self.first_site
    @@first_local_site ||= LocalSite.find(:first)
  end

  ## Cached db calls ==> whenever a new local site is added, mongrels would have to be restarted!
  ## In reality, very very very rare!
  @@local_sites = {}
  def self.cached_site_by_subdomain(subdomain, params={})
    if subdomain.blank? || (params[:local] && params[:local] == "false")
      nil
    else
      ls = @@local_sites[subdomain]
      if ls == 0
        nil
      elsif !ls.nil?
        ls
      else
        ls = LocalSite.find(:first, :conditions => {:subdomain => subdomain})
        @@local_sites[subdomain] = ls || 0
        ls
      end
    end
  end

  def self.clear_cached_sites
    @@local_sites = {}
  end

  # SSS: Is this dumb?  Is there a reason why a local site might submit stories that are not local? 
  def default_story_scope
    Story::StoryScope::LOCAL
  end

  def constraining_tag
    self.constraint ? self.constraint.name : nil
  end

  def constraining_tag=(tag_name)
    ct = Tag.find_or_create_by_name(tag_name)
    self.constraint_id = ct.id
  end

  def process_signup(member)
    if invitation_code
      existing_codes = (member.invitation_code || "").split(",").map(&:strip)
      if !existing_codes.grep(/#{invitation_code}/)
        # SSS: Flex attributes has a bug with "update_attribute"?
        member.update_attributes({"invitation_code" => existing_codes.empty? ? invitation_code : "#{member.invitation_code},#{invitation_code}"})
      end
    end
  end

  def subdomain_path
    @subdomain_path ||= "#{self.subdomain}.#{PRIMARY_DOMAIN.gsub(/^(.*\.)*([^\.]*\.[^\.]*)$/, "\\2")}"
  end

  def home_page
    "http://#{subdomain_path}"
  end

  def landing_page_subject_slugs
    self.subject_slugs.split(",").map(&:strip)
  end

  def subjects
    # This contorted code is to preserve order subjects are listed on the topics index page
    (landing_page_subject_slugs.collect { |slug| Subject.find_subject(slug, self) } + Subject.site_subjects(self)).uniq - Subject.site_subjects(self, :conditions => {:slug => ["us", "world", "extra", "local"]})
  end

  # This will always be run in a rake task few times a day -- so, can be slow
  def active_topics_by_subject(opts={})
    h = {}
    
    # Compute local site taggings count for all topics
    Topic.site_topics(self).collect { |t|
      num_taggings = Story.count(:joins => "JOIN taggings t1 ON t1.taggable_type='Story' AND t1.taggable_id = stories.id AND t1.tag_id = #{t.tag.id} JOIN taggings t2 ON t2.taggable_type='Story' AND t2.taggable_id = stories.id AND t2.tag_id = #{constraint.id}")
      t.subjects.each { |s|
        h[s.id] ||= []
        h[s.id] << [t.id, num_taggings] if num_taggings >= 3
      }
    }

    # Sort by frequency (descending order), and pick first 5
    h.keys.each { |s| h[s].sort! { |v1,v2| v2[1] <=> v1[1] }; h[s]= h[s].take(5)  }

    return h
  end

  protected

  def instantiate_taxonomy
    # Mirror topic taxonomy from national site
    Topic.find(:all, :conditions => {:local_site_id => nil}).each { |t|
      if t.class == Topic
        Topic.create(t.attributes.merge(:local_site_id => self.id))
      else
        Subject.create(t.attributes.merge(:local_site_id => self.id))
      end
    }

    # Mirror topic <-> subject relationships from national site
    # Requires cloning the entire set of topics & tags first
    TopicRelation.find(:all, :conditions => {:local_site_id => nil}).each { |tr|
      TopicRelation.create(tr.attributes.merge(:local_site_id => self.id, 
                                               :topic_id => Topic.tagged_topic_or_subject(tr.topic.tag, self).id, 
                                               :related_topic_id => Topic.tagged_topic_or_subject(tr.related_topic.tag, self).id))
    }
  end

  def initialize_sources
    # create a new source stats object for all public sources
    Source.find(:all, :select => "sources.id", :conditions => {:status => [Source::LIST, Source::FEATURE]}).each { |s|
      s.source_stats << SourceStats.create(:local_site_id => self.id)
    }

    # initialize stats for the new site
    SourceStats.find(:all, :select => "id", :conditions => {:local_site_id => self.id}).each { |ss|
      ss = SourceStats.find(ss.id)
      ss.update_review_stats # FIXME: shouldn't this get folded into the update_stats method below?
      ss.update_stats
    }
  end
end
