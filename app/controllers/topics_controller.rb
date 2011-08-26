class TopicsController < ApplicationController
  include LandingStoryListings
  include StoriesHelper

  APP_NAME = SocialNewsConfig["app"]["name"]
  @@all_topics_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["all_topics"]
  @@featured_topics_refresh_time = SocialNewsConfig["caching"]["refresh_times"]["featured_topics"]

  def index
    @subjects = @local_site.nil? ? Subject.national_subjects : @local_site.subjects

    respond_to do |format|
      format.html do render :layout => (params[:popup] ? "popup" : nil) end
      format.json do render :json => (Topic.all_topics(@local_site) + Subject.site_subjects(@local_site)).map{|t| {:name => t.name, :id => t.id}} end
    end
  end

  def show
    @topic = params[:id].to_i.zero? ? Topic.find_topic(params[:id], @local_site) : Topic.find(params[:id])
    raise ActiveRecord::RecordNotFound, "Page not found" if @topic.nil? || @topic.local_site != @local_site
    render_403(Topic) and return unless (@topic.is_public? || (current_member && current_member.has_role_or_above?(:editor)))

    @init_listing_type = :most_recent # Initial story listing

    @primary_subject = @topic.subjects.first
    @rss_autodiscovery_links = [ {:link => "/topics/#{@topic.slug}/most_recent.xml", :title => "#{APP_NAME}: #{@topic.name}: Top Stories"} ]

    # Load story listings -- order important
    # 1. feature story + story grid
    # 2. news comparison (without repeating stories in 1.)
    # 3. story listings
    top_area_story_ids = load_top_area_stories(@local_site, @topic)
    nc_story_ids       = load_right_column(@local_site, @topic, top_area_story_ids)
    listing_story_ids  = load_story_listing(@local_site, @topic, @init_listing_type)
    @num_stories       = listing_story_ids.length
    @cached_story_ids  = top_area_story_ids + nc_story_ids + listing_story_ids
    @is_ajax_listing   = false
    @url_tracking_key  = "tp"
    @has_story_listings = true
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def ajax_stories
    @topic = params[:id].to_i.zero? ? Topic.find_topic(params[:id], @local_site) : Topic.find(params[:id])
    raise ActiveRecord::RecordNotFound, "Page not found" if @topic.nil? || @topic.local_site != @local_site
    render_403(Topic) and return unless (@topic.is_public? || (current_member && current_member.has_role_or_above?(:editor)))

    listing_type = params[:listing_type].to_sym
    @cached_story_ids = load_story_listing(@local_site, @topic, listing_type)
    @is_ajax_listing = true
    @url_tracking_key = "tp"
    case listing_type
      when :starred
        render :partial => "shared/landing_pages/listings/starred", :locals => {:page_obj => @topic}
      when :todays_feeds
        render :partial => "shared/landing_pages/listings/todays_feeds"
      else
        render :partial => "shared/landing_pages/listings/default", :locals => {:page_obj =>@topic, :listing_type => listing_type, :listing_route => {:t_slug => @topic.slug}}
    end
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def all
    @cached_fragment_name = "all_topics"
    when_fragment_expired(@cached_fragment_name, @@all_topics_refresh_time.from_now) do
      @subjects = Subject.site_subjects(@local_site)
    end

    respond_to do |format|
      format.html { render :layout => (params[:popup] ? "popup" : nil) }
    end
  end

  def featured
    @cached_fragment_name = "featured_topics"
    when_fragment_expired(@cached_fragment_name, @@featured_topics_refresh_time.from_now) do
      @subjects = Subject.site_subjects(@local_site, :conditions => { :status => "feature"})
      @other_subjects = Subject.site_subjects(@local_site, :conditions => { :slug => ['education','health','media','religion']})
    end

    respond_to do |format|
      format.html { render :layout => (params[:popup] ? "popup" : nil) }
    end
  end
end
