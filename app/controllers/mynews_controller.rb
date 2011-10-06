require 'ostruct'

class MynewsController < ApplicationController
  include MynewsListing
  include MembersHelper
  include StoriesHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

    # Conditionally cache JSON & XML listing requests
    # Caution! It might seem that !c.request.format.html? should work ... but, if we get in an invalid format, that check will succeed!
  caches_page :stories, :if => Proc.new { |c| c.request.format.js? || c.request.format.json? || c.request.format.xml? || c.request.format.rss? }

  def mynews_home
    # No mynews on local sites, at least for now
    render_404 and return if !@local_site.nil?

    if logged_in?
      redirect_to mynews_url(current_member) 
    else
      store_location
      flash[:notice] = "Please Log In first to access MyNews."
      redirect_to new_sessions_path
    end
  end

  def refresh_fb_newsfeed
    @member = current_member
    f = @member.fbc_newsfeed
    f.fetch if f
    render :json => { :success => true }.to_json
  rescue FacebookConnect::MissingPermissions => e
    render :json => { :error => true, :noperms => true }.to_json
  rescue Exception => e
    render :json => { :error => true, :unknown => true }.to_json
  end

  def stories
    # No mynews on local sites, at least for now
    render_404 and return if !@local_site.nil?

    @member = Member.find(params[:member_id])
    respond_to do |format|
      format.html do 
        @url_tracking_key = "mn"
        @is_ajax_listing = true
        mynews_common
        render :layout => false, :partial => 'mynews/mynews_stories'
      end
      format.json do
        widget_params = { :listing_url => mynews_url(@member), :listing_type => nil, :listing_topic => "#{@member.name}'s MyNews" }
        if is_public_mynews?(@member) && @member.is_visible?
          mynews_common
        else
          @stories = []
          @access_denied_msg = "#{@member.name}'s MyNews listing can only be viewed by registered #{APP_NAME} members.  To see this member's MyNews, please signup (or login) on #{APP_NAME}, then visit <a href='#{mynews_url(@member)}'>#{mynews_url(@member)}</a>."
        end
        widget = widgetize_listing(widget_params, @stories)
        @metadata = widget[:metadata]
        @stories  = widget[:stories]
        render :layout => false, :template => "widgets/widgets.json.erb"
      end
      format.xml do
        # No RSS feeds if the member hasn't made the mynews page public because all our rss feeds are public by default.
        if is_public_mynews?(@member) && @member.is_visible?
          mynews_common
          @feed_data = {
            :feed_title  => "MyNews Feed for #{@member.name}",
            :listing_url => mynews_url(@member),
            :items       => @stories
          }
          @url_tracking_key = "mn_rss"
          render :layout => false, :template => "rss_feeds/stories.rss.builder"
        else
          @member_profile_url = mynews_url(@member)
          @access_denied_msg = "#{@member.name}'s MyNews listing can only be viewed by registered #{APP_NAME} members. To see this member's MyNews listing, please signup (or login) on #{APP_NAME}, then visit #{mynews_url(@member)}."
          render :layout => false, :template => "rss_feeds/access_denied.rss.builder"
        end
      end
    end
  end

  def mynews
    # No mynews on local sites, at least for now
    render_404 and return if !@local_site.nil?

    @member = Member.find(params[:member_id])

    unless is_public_mynews?(@member) || logged_in? # access control for non-public pages
      store_location
      flash[:notice] = "Please Log In first to access this MyNews page."
      redirect_to new_sessions_path and return 
    end

    # Check if this member's mynews page is accessible to the visitor
    unless is_visible_mynews?(@member)
      render_403(Member) and return
    end

    mynews_common
    @url_tracking_key = "mn"
    @has_story_listings = true
    @mynews_dropdown_settings_fields = MYNEWS_DROPDOWN_SETTINGS_FIELDS
    @mynews_checkbox_settings_fields = MYNEWS_CHECKBOX_SETTINGS_FIELDS
    if is_public_mynews?(@member)
      @rss_autodiscovery_links = [ {:link => "/members/#{@member.id}/mynews.xml", :title => "#{APP_NAME}: MyNews for #{@member.name}"} ]
    end
  end

  def update_setting
    @member = Member.find(params[:member_id])
    if @member != current_member
      error = "Trying to change settings of another member #{@member.id}.  I am #{current_member ? current_member.id : 'guest'}!"
      logger.error error
    else
      pref = params[:setting]
      if !MYNEWS_DEFAULT_SETTINGS.keys.include?(pref.to_sym)
        error = "Unknown setting: #{pref}"
      else
        error = nil
        @member.bypass_save_callbacks = true
        @member.update_attributes({pref => params[:value]})
      end
    end
    respond_to do |format|
      format.js do
        render :json => { :success => error.nil?, :error => error }.to_json
      end
    end
  end

  def update_settings
    @member = Member.find(params[:member_id])
    redirect_to access_denied_url if (@member != current_member)
    @member.bypass_save_callbacks = true
    @member.update_attributes(params[:mynews_settings].merge(params[:member] || {}))
    flash[:notice] = 'Your settings were successfully updated.'
    redirect_to mynews_url(@member)
  end

  def last_visit_at
    m1 = current_member
    m2 = Member.find(params[:member_id])
    if m1.nil?
      access_denied
    elsif (m1 == m2)
      n = 1 + (m1.mynews_num_visits || "0").to_i
      m1.bypass_save_callbacks = true
      m1.update_attributes({:mynews_last_visit_at => Time.now, :mynews_num_visits => n})
      respond_to do |format|
        format.js { render :inline => '', :status => '200' }
      end
    else
      n = 1 + (m2.mynews_num_guest_visits || "0").to_i
      m2.bypass_save_callbacks = true
      m2.update_attributes({:mynews_last_guest_visit_at => Time.now, :mynews_num_guest_visits => n})
      respond_to do |format|
        format.js { render :inline => '', :status => '200' }
      end
    end
  end

  private 

  def mynews_common
    @my_page = logged_in? && current_member == @member
    config_mynews(@member, @my_page)
  end
end
