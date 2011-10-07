class Admin::GroupsController < Admin::LandingPageController
  include Admin::LayoutHelper
  include MynewsListing

  # By default, all hosts get access to the groups page
  # But, some actions require staff access, others require editor or page host status
  grant_access_to :host
  before_filter :check_staff_access, :only => [:new, :create, :create_from_template, :destroy]
  before_filter :find_group, :except => [:index, :new, :create, :create_from_template]  # find_group BEFORE check_edit_access
  # Only editors and group hosts get edit & update access to the subject
  before_filter :check_edit_access,  :only => [:edit, :update, :config_group_mynews, :update_group_mynews_settings, :destroy_image]
  layout 'admin'

  # GET /admin/groups
  def index
    # Find all roles because there probably aren't as many as there will be regular groups.
    @roles = Role.find(:all).sort_by{ |x| x.name }

    # Find all internal groups since they are probably going to be restricted
    @internal_groups = Group.find(:all, :conditions => {:context => Group::GroupType::INTERNAL})

    # Lots of social groups!
    @social_groups = Group.paginate(:all, pagination_params.merge(:conditions => {:context => Group::GroupType::SOCIAL}))
  end
  
  # GET /admin/groups/new
  def new
    @group = Group.new
  end

  # GET /admin/groups/create_from_template
  def create_from_template
    @group = ModelTemplates.init_group
    flash[:notice] = "Social Group Created from template.<br/>Please edit <b>Name</b>, <b>Slug</b>, <b>Description</b>, and <b>dummy member details</b>."
    redirect_to edit_admin_group_path(@group)
  end

  def edit
    if @group.is_social_group?
      @flagged_comments = Flag.find(:all,
                                    :joins      => "JOIN comments on comments.id=flags.flaggable_id and flags.flaggable_type='Comment'", 
                                    :conditions => { "comments.commentable_type" => 'Group',
                                                     "comments.commentable_id" => @group.id,
                                                     :reason => "flag" })
      @tag_constraint_list = @group.selected_tags
      load_landing_page_layout_settings(@group)
    end
  end

  # POST /admin/groups
  def create
    if params[:group] && (params[:group][:context] == 'role')
      @group = Role.create(params[:group]) 
    else
      @group = Group.create(params[:group])
    end
    respond_to do |format|
      if @group.valid?
        flash[:notice] = "Group Created" + (@group.is_social_group? ? ".  Please configure it further below" : "")
        # For social groups, send them to the full-blown edit form!
        format.html { redirect_to(@group.is_social_group? ? edit_admin_group_path(@group) : admin_group_path(@group)) }
      else
        format.html { render :template => 'admin/groups/new' }
      end
    end
  end

  # PUT /admin/groups/1
  def update
    # Social group specific updates
    orig_slug = @group.slug
    valid = true
    if @group.is_social_group?
      # image
      update_image(@group, params)

      # story listings
      if params[:group][:no_tabs]
        @group.listings = ""
      else
        listings = params[:group].delete(:listings)
        @group.listings = listings.keys if listings
      end

      # tagging constraints
      tag_attrs = params[:group].delete(:tag_attributes)
      new_tag_ids = tag_attrs ? tag_attrs.collect { |ta| Tag.find_by_name(ta["name"]).id if ta["should_destroy"] != "true" }.compact : []
      params[:social_group_attributes][:tag_id_list] = new_tag_ids * ' '

      old_ids = @group.selected_tag_ids
      new_ids = new_tag_ids.sort
      @group.update_tag_selection(old_ids, new_ids) if old_ids != new_ids

      # social group specific attrs
      activate_flag = params[:social_group_attributes].delete(:activated)
      @group.sg_attrs.update_attributes(params[:social_group_attributes])

      # SSS: Looks like we are okay with no tabs!
      # valid = (SocialGroupAttributes::ATLEAST_ONE_THESE_LISTINGS.find { |t| @group.has_listing?(t) } != nil)
      # flash[:error] = "A group should have at least one of the these tabs: #{SocialGroupAttributes::ATLEAST_ONE_THESE_LISTINGS * ', '}" if !valid

      # landing page layout
      update_landing_page_layout(@group)
    end

    # Update group context last -- because when you switch to becoming a social group,
    # the update form wouldn't have all the social group attributes in place yet.
    @group.update_attribute(:context, params[:group][:context]) if params[:group] && params[:group][:context]

    # update common attributes
    @group.update_attributes(params[:group])
    if valid && @group.valid?
      # activate/deactivate
      if @group.is_social_group?
        activate_flag == "1" ? @group.activate! : @group.deactivate!
      end
      flash[:notice] = "Group updated<br/>" + (flash[:notice] || "") 
      # Redirect
      redirect_to(@group.is_social_group? ? group_path(@group) : edit_admin_group_path(@group))
    else
      validation_errors = (@group.errors.full_messages * "<br/>")
      validation_errors.gsub!(/Slug/, "Slug: #{@group.slug}")
      flash[:error] = "Could not update group settings.  Please correct errors below:<br/>" + validation_errors + (flash[:error] || "")
      # In case we failed uniqueness constraints on the slug!
      @group.slug = orig_slug
      redirect_to(edit_admin_group_path(@group))
    end
  end

  def config_group_mynews
    @mynews_dropdown_settings_fields = MYNEWS_DROPDOWN_SETTINGS_FIELDS
    @mynews_checkbox_settings_fields = MYNEWS_CHECKBOX_SETTINGS_FIELDS
    @member  = @group.sg_attrs.mynews_dummy_member
    @my_page = true
    config_mynews(@member, @my_page)
    render :layout => "application", :template => "mynews/mynews"
  end

  def update_group_mynews_settings
    # Can only modify mynews settings only if you are a host of the group or if you are staff
    if !current_member.has_host_privilege?(@group, :staff, @local_site)
      error = "Invalid request!  You do not have the privileges to change mynews settings for the group: #{@group.id}"
      logger.error error
      redirect_to access_denied_url and return
    end

    @member = @group.sg_attrs.mynews_dummy_member
    @member.bypass_save_callbacks = true
    @member.update_attributes(params[:mynews_settings].merge(params[:member] || {}))
    flash[:notice] = 'Your settings were successfully updated.'
    redirect_to config_group_mynews_admin_group_path(@group)
  end

  def destroy_image
    respond_to do |format|
      if @group.image && @group.image.destroy
        flash[:notice] = "Group's image deleted"
      else
        flash[:error] = "Group's image could not be deleted." 
      end
      format.html { redirect_to(edit_admin_group_path(@group))}
    end
  end
    
  # DELETE /admin/groups/1
  def destroy
    respond_to do |format|
      if @group.destroy
        flash[:notice] = "Group Destroyed"
        format.html { redirect_to(admin_groups_path) }
      else
        flash[:error]= @group.errors.full_messages.join('<br/>')
        format.html { redirect_to(edit_admin_group_path(@group)) }
      end
    end
  end

end
