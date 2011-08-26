class GroupsController < ApplicationController
  include MynewsListing
  include LandingStoryListings
  include StoriesHelper

  before_filter :find_group, :only => [:show, :members, :ajax_stories, :join_group, :leave_group]
  before_filter :check_group_access, :only => [:show, :members]
  before_filter :login_required, :only => [:join_group, :leave_group]

  def index
    render :template => "pages/groups"
  end

  def show
    # Load story listings -- order important
    # 1. feature story + story grid
    # 2. news comparison (without repeating stories in 1.)
    # 3. story listing for the initial tab
    #
    # For groups, behavior is identical on all sites -- local sites don't matter.
    # So, I am going to ignore @local_site here
    top_area_story_ids = load_top_area_stories(nil, @group)
    nc_story_ids       = load_right_column(nil, @group, top_area_story_ids)
    if @group.no_listings?
      @no_listings = true
      @has_story_listings = false
    else
      @init_listing_type = (@group.sg_attrs.default_listing || SocialGroupAttributes::ATLEAST_ONE_THESE_LISTINGS.find { |t| @group.has_listing?(t) }).to_sym
      if @init_listing_type == :activity
        @will_be_cached = false
        @group_activities = @group.member_activity(params[:last_activity_entry_id])
        @group_activity_hash = ActivityEntry.activity_object_hash(@group_activities)
        listing_story_ids = []
      elsif @init_listing_type == :new_stories
        @will_be_cached = false
        load_story_listing(nil, @group, @init_listing_type)
        listing_story_ids = []
      else
        @will_be_cached = true
        listing_story_ids = load_story_listing(nil, @group, @init_listing_type)
      end
      @cached_story_ids  = top_area_story_ids + nc_story_ids + listing_story_ids
      @num_stories       = listing_story_ids.length
      @is_ajax_listing   = false
      @url_tracking_key  = "gp_#{@group.slug}"
      @has_story_listings = true
    end
  rescue ActiveRecord::RecordNotFound
    render_404 and return
  end

  def members
  end

  def ajax_stories
    raise ActiveRecord::RecordNotFound, "Page not found" if @group.nil?
    render_403(Group) and return unless (@group.activated? || (current_member && current_member.has_role_or_above?(:editor)))

    # For groups, behavior is identical on all sites -- local sites don't matter.
    # So, I am going to ignore @local_site
    @is_ajax_listing = true
    @url_tracking_key = "gp_#{@group.slug}"
    listing_type = params[:listing_type].to_sym
    if listing_type == :new_stories
      @will_be_cached = false
      load_story_listing(nil, @group, listing_type)
      render :partial => "shared/landing_pages/listings/mynews" 
    elsif listing_type == :activity
      more_entries_request = !params[:last_activity_entry_id].blank?
      @will_be_cached = false
      @cached_story_ids = []
      @group_activities = @group.member_activity(params[:last_activity_entry_id])
      @group_activity_hash = ActivityEntry.activity_object_hash(@group_activities)
      render_landing_page_listing({:partial => "shared/landing_pages/listings/#{more_entries_request ? "activity_listing_entries" : "activity"}",
                                   :type    => listing_type,
                                   :locals  => {:group => @group, :activities => @group_activities, :activity_hash => @group_activity_hash}}, @group)
    else
      @will_be_cached = true
      @cached_story_ids = load_story_listing(nil, @group, listing_type)
      render_landing_page_listing({:type => listing_type}, @group, {:listing_route => {:g_slug => @group.id}})
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.error "Exception #{e}; Backtrace: #{e.backtrace * '\n'}"
    render_404 and return
  end

  def join_group
    m = current_member
    added = @group.has_member?(m) ? true : @group.add_member(m) 
    if added
      flash[:notice] = "You are now a member of this group"
    else
      flash[:error] = "We are sorry! There was an error adding you to the group. Please email the hosts to join this group"
    end
    redirect_to group_path(@group)
  end

  def leave_group
    m = current_member
    if @group.hosts.include?(m)
      flash[:error] = "You are a host. You cannot leave this group!"
    elsif !@group.has_member?(m)
      flash[:error] = "You are not a member of this group."
    elsif @group.remove_member(m)
      flash[:notice] = "You have been removed from the group."
    else
      flash[:error] = "We are sorry! There was an error removing you from the group. Please email the hosts to be removed from this group."
    end
    redirect_to group_path(@group)
  end

  protected

  def find_group
    @group = Group.find_by_id_or_slug(params[:id])
  end

  def check_group_access
    raise ActiveRecord::RecordNotFound, "Page not found" if @group.nil?
    render_404 and return if !@group.is_social_group?
    render_403(Group) and return unless ((@group.activated? && !@group.sg_attrs.hidden?) || (logged_in? && current_member.has_host_privilege?(@group, :editor)))
    render_403(Group) and return unless @group.visible_to_member?(current_member)
  end
end
