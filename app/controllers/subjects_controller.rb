class SubjectsController < ApplicationController
  include LandingStoryListings
  include StoriesHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  def show
    @subject = params[:subject_id].to_i.zero? ? Subject.find_subject(params[:subject_id], @local_site) : Subject.find(params[:subject_id])
    raise ActiveRecord::RecordNotFound, "Page not found" if @subject.nil? || @subject.local_site != @local_site

    @init_listing_type = :most_recent # Initial story listing

    # Because the params use "subject_id" instead of "id", we need to manually set the record id for the email form.
    @record_id = params[:subject_id]
    @rss_autodiscovery_links = [ {:link => "/subjects/#{@subject.slug}/most_recent.xml", :title => "#{APP_NAME}: #{@subject.name}: Top Stories"} ]

    # Load story listings -- order important
    # 1. feature story + story grid
    # 2. news comparison (without repeating stories in 1.)
    # 3. story listings
    top_area_story_ids = load_top_area_stories(@local_site, @subject)
    nc_story_ids       = load_right_column(@local_site, @subject, top_area_story_ids)
    listing_story_ids  = load_story_listing(@local_site, @subject, @init_listing_type)
    @num_stories       = listing_story_ids.length
    @cached_story_ids  = top_area_story_ids + nc_story_ids + listing_story_ids
    @is_ajax_listing   = false
    @url_tracking_key   = "tp"
    @has_story_listings = true
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def ajax_stories
    @subject = params[:subject_id].to_i.zero? ? Subject.find_subject(params[:subject_id], @local_site) : Subject.find(params[:subject_id])
    raise ActiveRecord::RecordNotFound, "Page not found" if @subject.nil? || @subject.local_site != @local_site

    listing_type = params[:listing_type].to_sym
    @cached_story_ids = load_story_listing(@local_site, @subject, listing_type)
    @is_ajax_listing = true
    @url_tracking_key = "tp"
    case listing_type
      when :starred
        render :partial => "shared/landing_pages/listings/starred", :locals => {:page_obj => @subject}
      when :todays_feeds
        render :partial => "shared/landing_pages/listings/todays_feeds"
      else
        render :partial => "shared/landing_pages/listings/default", :locals => {:page_obj => @subject, :listing_type => listing_type, :listing_route => {:s_slug => @subject.slug}}
    end
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end
end
