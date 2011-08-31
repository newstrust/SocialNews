class SourcesController < ApplicationController
  before_filter :find_source, :except => [:index, :list, :create, :search, :trusted, :rate_sources, :rate_by_medium]
  before_filter :login_required, :except => [ :index, :list, :show, :ajax_stories, :new, :destroy, :search, :trusted, :rate_sources, :rate_by_medium, :source_reviews ]

  APP_NAME = SocialNewsConfig["app"]["name"]
  include ApplicationHelper
  include StoriesHelper

  @@sources_index_page_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["sources_index_page"]
  @@source_landing_page_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["source_landing_page"]
  @@trusted_sources_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["trusted_sources"]

  def index
    respond_to do |format|
      format.html do
        @cached_fragment_name = get_cached_fragment_name("sources_index", nil)
        when_fragment_expired(@cached_fragment_name, @@sources_index_page_refresh_time.seconds.from_now) do
          fetch_sources_for_index
        end
      end

      format.json do
        find_opts = {:conditions => {:status => ["hide", "list", "feature"]}}
        @sources = @local_site.nil? ? Source.find(:all, find_opts) : @local_site.sources.find(:all, find_opts)
        render :json => @sources.map{|s| {:name => s.name, :id => s.id}} 
      end
    end
  end

  def rate_sources
    fetch_sources_for_index(20)
    @my_reviews_hash = {}
    if logged_in?
      SourceReview.for_site(@local_site).for_member(current_member).find(:all, :conditions => {:source_id => @sources.collect { |k,v| v }.flatten.map(&:id)}).each { |sr|
        @my_reviews_hash[sr.source_id] = sr
      }
    end
  end

  # GET /sources/search
  def search
      # Search by name -- not by all fields
    @results = empty_query? ? [] : Source.search(:conditions => {:name =>  params[:q]})
    respond_to do |format|
      format.js do
          ## Only show listed/featured sources
        tmp = @results.reject { |x| !(x && (x.status == 'list' || x.status == 'feature')) }.compact.map {|x| "#{x.name}|#{x.slug}" }.compact.join("\n")
        render :json => tmp.to_json
      end
    end
  end

  # for now, just list by medium
  def list
    find_sources_by_medium
  end

  # for now, just list by medium
  def rate_by_medium
    find_sources_by_medium
    @my_reviews_hash = {}
    if logged_in?
      SourceReview.for_site(@local_site).for_member(current_member).find(:all, :conditions => {:source_id => @sources.map(&:id)}).each { |sr|
        @my_reviews_hash[sr.source_id] = sr
      }
    end
  end

  def show
    render_403(Source) and return unless @source.is_public? or (logged_in? and current_member.has_role_or_above?(:editor))

    @url_tracking_key = "sp"
    @has_story_listings = true

    @rss_autodiscovery_links = (@source.status == Source::PENDING) ? [] : [ {:link => "/sources/#{@source.slug}/most_recent.xml", :title => "#{APP_NAME}: Top Stories from #{@source.name}"} ]
    @cached_top_area_fragment_name = get_cached_fragment_name("source_top_area=" + @source.id.to_s, nil)
    when_fragment_expired(@cached_top_area_fragment_name, @@source_landing_page_refresh_time.seconds.from_now) {}

    # Start off with the most_recent tab!
    @cached_story_ids = get_listing(:new_stories)

    @cached_right_column_fragment_name = get_cached_fragment_name("source_right_column=" + @source.id.to_s, nil)
    when_fragment_expired(@cached_right_column_fragment_name, @@source_landing_page_refresh_time.seconds.from_now) do
      # SSS: Turning off this block now -- too many ratings being displayed on the source page
      # @current_member_rating = @source.average_rating_by_member(current_member)
    end
  end

  def source_reviews
    conds = [@local_site ? ["local_site_id = ?", @local_site.id] : ["local_site_id IS NULL"]]
    conds << ["source_id = ?", @source.id]
    @source_reviews = SourceReview.paginate(:all, pagination_params.merge(:per_page => params[:per_page] || 20, 
                                                                          :conditions => QueryHelpers.conditions_array(conds), 
                                                                          :order => "updated_at DESC"))
  end

  def ajax_stories
    render_403(Source) and return unless @source.is_public? or (logged_in? and current_member.has_role_or_above?(:editor))

    @url_tracking_key = "sp"
    @has_story_listings = true
    @is_ajax_listing = true
    listing_type = params[:listing_type].to_sym
    if listing_type != :source_reviews
      @cached_story_ids = get_listing(listing_type)
      render :partial => "sources/listing", :locals => {:listing_type => listing_type}
    else
      @member_source_review = @source.source_review_by_member(@local_site, current_member) if logged_in?

      # Fetch source reviews: first with notes, and then without notes
      total_reqd = 10
      num_reqd = total_reqd
      
      # note, rating, expertise
      @source_reviews  = find_source_reviews(num_reqd, [], :with_note => true, :with_rating => true, :with_expertise => true)
      num_reqd = total_reqd - @source_reviews.length

      # note, rating
      @source_reviews += find_source_reviews(num_reqd, @source_reviews, :with_note => true, :with_rating => true) if num_reqd > 0
      num_reqd = total_reqd - @source_reviews.length

      # note, expertise
      @source_reviews += find_source_reviews(num_reqd, @source_reviews, :with_expertise => true, :with_note => true) if num_reqd > 0
      num_reqd = total_reqd - @source_reviews.length

      # rating, expertise
      @source_reviews += find_source_reviews(num_reqd, @source_reviews, :with_expertise => true, :with_rating => true) if num_reqd > 0
      num_reqd = total_reqd - @source_reviews.length

      # Anything goes!
      @source_reviews += find_source_reviews(num_reqd, @source_reviews) if num_reqd > 0

      # Render
      render :partial => "sources/source_reviews_listing"
    end
  end

  def trusted
    @cached_fragment_name = "trusted_sources"
    when_fragment_expired(@cached_fragment_name, @@trusted_sources_refresh_time.from_now) { }

    respond_to do |format|
      format.html do render :layout => (params[:popup] ? "popup" : nil) end
    end
  end

  def new
    @source = Source.new(:source_date => Time.now)
  end

  def edit
  end

  def create
    @source = Source.new(params[:source].merge(last_edited_params))

    if @source.save
      redirect_to @source
    else
      render :action => "new"
    end
  end

  def update
    if @source.update_attributes(params[:source].merge(last_edited_params))
      flash[:notice] = 'Source was successfully updated.'
      redirect_to source_path(@source.to_param)
    else
      render :action => "edit"
    end
  end

  def destroy
    if (!@source.destroy)
      flash[:error] = "Source #{@source.id} has stories assigned to it.  Cannot delete the source till all those stories are re-assigned / deleted."
    end
    redirect_to sources_url
  end

  def edit_source_review
    render :partial => "source_reviews/form", :locals => {:source_review => @source.source_review_by_member(@local_site, current_member), :show_form => true, :is_ajax_request => true}
  end

  protected

  def find_source
    @source = Source.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    render_404 and return
  end

  def find_sources_by_medium
    smi = Source.source_medium_info(params[:medium])
    if smi.nil?
      logger.error "Unknown source medium: #{params[:medium]}"
      render_404 and return
    end

    @medium_name = smi["name"]
    @sources = @local_site.nil? ? Source.list_visible_by_medium(params[:medium]) \
                                : Source.list_by_medium(params[:medium], 
                                                        :joins => "JOIN local_sites_sources ON local_sites_sources.source_id = sources.id",
                                                        :conditions => ["local_sites_sources.local_site_id = #{@local_site.id}"])
  end

  def find_source_reviews(n, to_exclude, opts={})
    opts[:with_ratings]   ||= false
    opts[:with_note]      ||= false
    opts[:with_expertise] ||= false

    conds = []
    conds << (@local_site ? ["local_site_id = ?", @local_site.id] : ["local_site_id IS NULL"])
    conds << ["source_id = ?", @source.id]
    conds << ["member_id != ?", current_member.id] if logged_in?
    conds << ["source_reviews.status != ?", Status::HIDE] if !logged_in? || !current_member.has_role_or_above?(:admin)
    conds << ["source_reviews.rating != 0"] if opts[:with_rating]
    conds << ["source_reviews.expertise_topic_ids != ''"] if opts[:with_expertise]
    conds << ["note != ''"] if opts[:with_note]
    conds << ["source_reviews.id NOT IN (?)", to_exclude] if !to_exclude.blank?

    SourceReview.find(:all, 
                      :joins => "JOIN members USE INDEX(index_members_on_rating) ON members.id=source_reviews.member_id",
                      :conditions => QueryHelpers.conditions_array(conds),
                      :order => "members.rating DESC",
                      :limit => n)
  end

  def get_listing(listing_type)
    # IMPORTANT: Pass source id, not slug, because slug can sometimes be null (ex: pending sources)
    @cached_listing_fragment_name = get_cached_fragment_name("source_#{listing_type}=" + @source.id.to_s, nil)
    @cached_story_ids = get_cached_story_ids_and_when_fragment_expired(@cached_listing_fragment_name, @@source_landing_page_refresh_time.seconds) do
      @will_be_cached = true
      opts = { :listing_type => listing_type, :filters => { :local_site => @local_site, :sources => {:id => @source.id} } }
      # 90 days for most-trusted
      if listing_type.to_sym == :most_trusted
        @timespan = 90
        opts[:filters][:time_span] = @timespan.days 
      end
      @stories = Story.list_stories_with_associations(opts)
      @tab_to_select = listing_type

        # Last statement in block should yield a flat list of stories
      @stories.flatten.map(&:id)
    end
  end

  def fetch_sources_for_index(limit_per_cat=15)
    @sources = {}
    Source.each_source_medium { |key, medium|
      if @local_site.nil?
        @sources[key] = Source.top_rated_by_medium(key, :no_local_scope => true, :limit => limit_per_cat).sort{|x, y| x["name"] <=> y["name"]}
      else
        @sources[key] = Source.list_by_medium(key, :joins => "JOIN local_sites_sources ON local_sites_sources.source_id = sources.id",
                                                   :conditions => ["local_sites_sources.local_site_id = ? AND sources.rating >= ?", @local_site.id, SocialNewsConfig["min_source_rating"]])
      end
    }
  end
end
