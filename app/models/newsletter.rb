class Newsletter < ActiveRecord::Base
  include MembersHelper
  include MailerHelper
  require 'lib/string_helpers'

  has_many :newsletter_stories, :dependent => :delete_all
  has_many :newsletter_recipients, :dependent => :delete_all
  has_many :stories, :through => :newsletter_stories
  has_many :members, :through => :newsletter_recipients

  belongs_to :local_site

  before_save :linewrap_text_header_footer

  NEW        = "new"
  AUTO       = "auto"       ## Automatically generated newsletter -- in situations where an editor has not edited the newsletter
  READY      = "ready"
  IN_TRANSIT = "in_transit"
  SENT       = "sent"

  MYNEWS           = "mynews"
  DAILY            = "daily"
  WEEKLY           = "weekly"
  DISABLED_NEWSLETTERS   = []
  VALID_NEWSLETTER_TYPES = [DAILY, WEEKLY, MYNEWS] - DISABLED_NEWSLETTERS

  BULK = "special" # SSS: Hmm ... why break in convention?

  DELIVERY_TIMES = {}
  (VALID_NEWSLETTER_TYPES+DISABLED_NEWSLETTERS).each { |nl_type| DELIVERY_TIMES[nl_type] = SocialNewsConfig["bj"]["newsletter_dispatch_times"][nl_type] }

  # Set up a logger
  @logger = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}_newsletter.log")
  @logger.formatter = RailsFormatter.new

  def self.clear_pending_dispatches(freq)
    Bj.table.job.find(:all, :conditions => {:tag => "newsletter_#{freq}", :state => "pending"}).each { |j| j.destroy }
  end

  def self.fetch_prepared_newsletter(freq)
    nl = find(:first, :conditions => [ "(state = 'auto' OR state = 'ready' OR state = 'in_transit') AND freq = ?", freq ])

      # Auto-generated newsletters always use the latest stories
    nl.refresh_stories if (nl && nl.state == AUTO)

    return nl
  end

  def self.fetch_latest_newsletter(freq, requester)
      # Fetch the latest unsent newsletter -- create one, if necessary
      # There can only be one such newsletter per newsletter frequency
    nl = find(:first, :conditions => [ "state != 'sent' AND freq = ?", freq ])
    if nl.nil?
        ## didn't find one -- create a new newsletter
      nl = Newsletter.new

        ## Newsletters are *always ready* for dispatch
      nl.state = (requester == Member.nt_bot) ? AUTO : READY
      nl.freq = freq

        ## Compute the dispatch time for this newsletter
      nl.dispatch_time = Newsletter.get_next_dispatch_time(freq)

        ## Save so that the initialization can add stories to the newsletter
      nl.save!

        ## initialize the newsletter's stories, and set up subject, headers & footers from templates
        ## these can then be edited by the editor / admin.
      nl.init_newsletter
      nl.update_attribute("refreshed_at", Time.now)

        ## Submit for dispatch
      nl.submit_to_bj

        ## Add a log entry!
      nl.log_action "Set up by #{requester.id}:#{requester.name} at #{nl.created_at}"
    elsif (nl.state == AUTO)
        ## Auto-generated newsletters always use the latest stories
      nl.refresh_stories
    end
    nl
  end

  def self.get_next_dispatch_time(freq)
    case freq 
      when DAILY  then Newsletter.get_next_daily_dispatch_time(DAILY, WEEKLY)
      when WEEKLY then Newsletter.get_next_weekly_dispatch_time(WEEKLY)
      when MYNEWS then Newsletter.get_next_mynews_dispatch_time
      else nil
    end
  end

  def self.url_tracking_key(freq)
    case freq 
      when DAILY  then "nld"
      when WEEKLY then "nlw"
      when MYNEWS then "nlm"
      else nil
    end
  end

  def self.subscriber_ids(freq)
    Member.find(:all,
                :select => "members.id",
                :joins => [:newsletter_subscriptions],
                :conditions => ["newsletter_subscriptions.newsletter_type = ? AND members.id != ? AND status IN ('member', 'duplicate')", freq, Member.nt_bot.id, ])
  end

    # Order important -- this decides what sources get stories in what listing since sources are not to be duplicated across all listings
  def self.newsletter_sections_iterator
    ["most_recent", "most_trusted"].each { |lt| [Story::NEWS, Story::OPINION].each { |st| [Source::MSM, Source::IND].each { |so| yield(lt, st, so) } } }
  end

    # Convenience named methods for fetching specific story types
  self.instance_eval do
    Newsletter.newsletter_sections_iterator { |listing_type, story_type, source_ownership|
      nl_listing_type = "#{listing_type}_#{story_type}_#{source_ownership}"
      define_method("#{nl_listing_type}") { stories(listing_type, story_type, source_ownership) }
    }
  end

  def main_sections
    ["most_recent", "most_trusted"]
  end

  def stories(listing_type, story_type, source_ownership)
    Story.find(:all,
               :joins => "JOIN newsletter_stories ns ON ns.story_id = stories.id",
               :conditions => [ "ns.newsletter_id = ? AND ns.listing_type = ?", self.id, "#{listing_type}_#{story_type}_#{source_ownership}" ],
               :order => "ns.id")
  end

  def log_action(msg)
    Newsletter.logger.info "#{freq.humanize} Newsletter #{id}: #{msg}"
  end

  def log_error(msg)
    Newsletter.logger.error "#{freq.humanize} Newsletter #{id}: #{msg}"
  end

  def associated_local_site
    # SSS FIXME: This is hardcoded!
    nil
  end

  def self.humanized_freq(freq)
    case freq
      when BULK then "Special Notices"
      when MYNEWS then "MyNews Daily Email"
      else freq.split('_').map(&:capitalize).join(' ') + " Newsletter"
    end
  end

  def self.humanized_dispatch_time(freq, opts = {})
    sent = opts[:no_sent] ? "" : "Sent "
    case freq
      when BULK then "#{sent}as needed"
      when MYNEWS, DAILY then "#{sent}every day at #{delivery_time(freq)}"
      when WEEKLY then "#{sent}every #{SocialNewsConfig["newsletter"]["weekly_delivery_display_text"]}"
    end
  end

  def humanized_name(abbreviated=false)
    case self.freq
      when DAILY  then "Today's"
      when WEEKLY then "This Week's"
      else ""
    end
  end

  def init_newsletter
    if freq != MYNEWS
      self.add_top_story_title_to_subject = true
      init_stories
    end
    init_template
    save!
  end

  def refresh_stories
      # Nothing to refresh for mynews newsletters
    return if freq == MYNEWS

      # If the newsletter is being sent out, no refresh!
    return if self.state == IN_TRANSIT

    newsletter_stories.clear
    init_stories

    self.update_attribute(:refreshed_at, Time.now)
  end

  def submit_to_bj
      ## No queueing of disabled newsletters!
    return if disabled?

      ## Get rid of any pending jobs for the 'freq' newsletter -- there can be atmost one job queued for each kind of newsletter
    Newsletter.clear_pending_dispatches(freq)

      ## Add it to the Bj dispatch queue!
    jobs = Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:newsletter:dispatch freq=#{freq}", :submitted_at => dispatch_time, :tag => "newsletter_#{freq}", :priority => SocialNewsConfig["bj"]["priorities"]["newsletter_dispatch"]

    self.bj_job_id = jobs.first.id
    save!
  end

  def mark_in_transit
    self.state = IN_TRANSIT
    self.save
  end

  def mark_sent
    self.state = SENT
    self.save
  end

  def is_mynews?
    freq == MYNEWS
  end

  def is_daily?
    [DAILY].include?(freq)
  end

  def is_weekly?
    [WEEKLY].include?(freq)
  end

  def disabled?
    DISABLED_NEWSLETTERS.include?(freq)
  end

  def can_dispatch?
    ((state == AUTO) || (state == READY) || (state == IN_TRANSIT))
  end

  def get_delivery_notice(recipient)
    newsletter_recipients.find(:first, :conditions => {:member_id => recipient.id})
  end

  def record_delivery_notice(recipient)
    newsletter_recipients << NewsletterRecipient.new(:member => recipient)
  end

  # The newsletter bodies (text & html), and the full subject line are setup just before dispatch -- they are not stored in the db
  attr_accessor :text_body, :html_body, :subject_line

  def linewrap_text_header_footer
      ## Line-wrap the header & footer
    self.text_header = StringHelpers.linewrap_text(self.text_header, SocialNewsConfig["newsletter"]["max_line_length"]) if self.text_header
    self.text_footer = StringHelpers.linewrap_text(self.text_footer, SocialNewsConfig["newsletter"]["max_line_length"]) if self.text_footer
  end

  private

  def self.logger; @logger; end

  # Return the newsletter delivery time in PT and ET
  # SSS: NOTE: This is fragile -- assumes that the timezone of the server is set to PT.
  def self.delivery_time(freq)
    hour = Newsletter::DELIVERY_TIMES[freq]["hour"]
    min = Newsletter::DELIVERY_TIMES[freq]["min"]
		pt = Time.parse("#{hour}:#{min}")
		et = Time.parse("#{hour + 3}:#{min}")
		return "#{et.strftime("%I%p").gsub(/^0/, '').downcase} ET (#{pt.strftime("%I%p").gsub(/^0/, '').downcase} PT)"	  
  end

  def init_stories
    story_lists = {}
    main_sections.each { |lt|
      story_lists[lt] = {}
      [Story::NEWS, Story::OPINION].each { |st|
        story_lists[lt][st] = {}
        @excluded_source_ids = []
        [Source::MSM, Source::IND].each { |so| 
            # since we have eliminated one-story-per-source constraint across the page, we may have a story that has at least 3 reviews
            # and be listed in both the top-stories and top-rated section ... so, find such stories from top-stories and add it to the
            # exclude list when fetching top-rated
          exclude_stories_ids = []
          story_lists["most_recent"][st][so].each { |s| exclude_stories_ids << s.id if !s.hide_rating } if (lt == "most_trusted")
          story_lists[lt][st][so] = setup_stories(lt, st, so, exclude_stories_ids) 
        }
      }
    }
  end

  def setup_stories(listing_type, story_type, source_ownership, exclude_stories_ids)
    local_site = self.associated_local_site
    max_stories_per_source = LocalSite.max_stories_per_source(local_site)

    if local_site
      # Pick local-site settings if those settings are available.  If not, default to national site
      nl_consts = SocialNewsConfig["newsletter"][local_site.slug] || SocialNewsConfig["newsletter"]
    else
      nl_consts = SocialNewsConfig["newsletter"]
    end

    nl_listing_type = "#{listing_type}_#{story_type}_#{source_ownership}"
    num_stories = nl_consts["num_" + nl_listing_type]

    stories = Story.list_stories({
                :listing_type => listing_type.to_sym,
                :per_page     => num_stories,
                :filters      => { :no_local => true,
                                   :story_type => story_type,
                                   :exclude_stories => exclude_stories_ids,
                                   :local_site => local_site,
                                   :sources => {
                                     :max_stories_per_source => max_stories_per_source, ## Add source diversity constraint
                                     :exclude_ids => @excluded_source_ids, 
                                     :ownership => source_ownership 
                                   } 
                                 }
              })

    # Update set of sources with stories listed on the page
    @source_counts ||= {}
    stories.each { |s|
      src_id = s.primary_source.id
      @source_counts[src_id] ||= 0
      @source_counts[src_id] += 1
      @excluded_source_ids << src_id if @source_counts[src_id] == max_stories_per_source
    }

      # Create newsletter stories out of these! 
    stories.each { |s| newsletter_stories << NewsletterStory.new(:story => s, :listing_type => nl_listing_type) }

    return stories
  end

  def init_template
    prev_newsletter = Newsletter.find(:first, :conditions => { :freq => freq, :state => SENT }, :order => "id desc")
    if prev_newsletter.nil?
      self.subject     = ""
      self.text_header = ""
      self.text_footer = ""
      self.html_header = ""
      self.html_footer = ""
    else
      self.subject     = prev_newsletter.subject
      self.text_header = prev_newsletter.text_header
      self.text_footer = prev_newsletter.text_footer
      self.html_header = prev_newsletter.html_header
      self.html_footer = prev_newsletter.html_footer
    end
  end

    ## Got to do this jumping-the-hoop because BJ doesn't have cron-like submission feature
  def self.get_next_weekly_dispatch_time(weekly_freq)
    t1 = Time.now
    t2 = t1.beginning_of_week + (DELIVERY_TIMES[weekly_freq]["day"]-1).days + DELIVERY_TIMES[weekly_freq]["hour"].hours + DELIVERY_TIMES[weekly_freq]["min"].minutes
    t2 += 7.days if t2 < t1

      # If some editor overrode the schedule and sent out a newsletter, make sure
      # a new one is not scheduled within the same week!
      #
      # Or, if we change time because of daylight saving time changes, make sure multiple ones don't go out!
    latest_sent = Newsletter.find(:first, :conditions => {:freq => WEEKLY, :state => SENT}, :order => "dispatch_time DESC")
    t2 += 7.day if latest_sent && (t2 - latest_sent.dispatch_time) < 6.days

    return t2
  end

    ## Got to do this jumping-the-hoop because 
    ## (a) BJ doesn't have cron-like submission feature
    ## (b) On the day a weekly newsletter is sent, a daily newsletter cannot be sent
  def self.get_next_daily_dispatch_time(daily_freq, weekly_freq)
    t1 = Time.now
    t2 = t1.beginning_of_day + DELIVERY_TIMES[daily_freq]["hour"].hours + DELIVERY_TIMES[daily_freq]["min"].minutes
    t2 += 1.day if t2 < t1

      # If some editor overrode the schedule and sent out a newsletter today, make sure a new one is not scheduled today!
      # Or, if we change time because of daylight saving time changes, make sure multiple ones don't go out!
    latest_sent = Newsletter.find(:first, :conditions => {:freq => daily_freq, :state => SENT}, :order => "dispatch_time DESC")
    t2 += 1.day if latest_sent && (latest_sent.dispatch_time.day == t2.day)

      # On the day a weekly newsletter is sent, there is no daily newsletter!
    t2 += 1.day if (t2.to_date.cwday == DELIVERY_TIMES[weekly_freq]["day"])

    return t2
  end

  def self.get_next_mynews_dispatch_time
    t1 = Time.now
    t2 = t1.beginning_of_day + DELIVERY_TIMES[MYNEWS]["hour"].hours + DELIVERY_TIMES[MYNEWS]["min"].minutes
    t2 += 1.day if t2 < t1

      # If some editor overrode the schedule and sent out a newsletter today, make sure a new one is not scheduled today!
      # Or, if we change time because of daylight saving time changes, make sure multiple ones don't go out!
    latest_sent = Newsletter.find(:first, :conditions => {:freq => MYNEWS, :state => SENT}, :order => "dispatch_time DESC")
    t2 += 1.day if latest_sent && (latest_sent.dispatch_time.day == t2.day)

    return t2
  end

end
