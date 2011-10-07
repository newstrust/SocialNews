class Admin::LocalSitesController < Admin::AdminController
  include Admin::LayoutHelper

  # By default, all hosts get access to the local sites index page 
  # * Some actions require editorial access
  # * Others require editor access or for them to be hosts of those local sites
  grant_access_to :host
  before_filter :find_local_site,   :only => [:edit, :update]
  before_filter :check_access,      :only => [:new, :create]
  # Only staff and local_site hosts get edit & update access to an individual local_site
  before_filter(:only => [:edit, :update]) { |controller| controller.send(:check_edit_access, :staff) }

  layout 'admin'

# -----------------------------------------------------------------------------------------
# SSS: Important: Do not rename @lsite to @local_site  in this controller.
# @local_site is used as a global attribute to refer to the currently active local site.
# If your rename that attribute to something else, say @active_site or @active_local_site,
# you could use @local_site here.
# -----------------------------------------------------------------------------------------

  def index
    @lsites = LocalSite.find(:all)
  end

  def new
    @lsite = LocalSite.new
  end

  def destroy
    flash[:error] = "Cannot destroy local sites from the front-end"
    redirect_to(admin_local_sites_path)
  end

  def create
    @lsite = LocalSite.new(params[:lsite])
    if @lsite.save!
      LocalSite.clear_cached_sites
      flash[:notice] = "Local Site '#{@lsite.name}' successfully created!<br/>"
      flash[:notice] += "Until you set up the local site homepage, you may not be able to view the homepage.  Go to 'Admin -> Home' and save that page without changes.  That should suffice for starters."
      redirect_to(admin_local_sites_path)
    else
      render :template => 'admin/local_sites/new'
    end
  rescue Exception => e
    flash[:error] = "Error creating local_site!"
    logger.error "Exception #{e}; #{e.backtrace.inspect}"
    render :template => 'admin/local_sites/new'
  end

  def edit
  end

  def update
    # Save!
    if @lsite.update_attributes(params[:lsite]) 
      LocalSite.clear_cached_sites
      redirect_to(admin_local_sites_path)
    else
      render :template => 'admin/local_sites/edit'
    end
  rescue Exception => e
    flash[:error] = "Error updating local_site!"
    logger.error "Exception #{e}; #{e.backtrace.inspect}"
    render :template => 'admin/local_sites/edit'
  end

  protected
  def check_access
    # By default, all hosts get access to the local_sites admin page -- but all actions except edit & update require staff level
    redirect_to access_denied_url and return unless logged_in? && current_member.has_role_or_above?(:staff)
  end


  def find_local_site
    @lsite = LocalSite.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_local_sites_path
  end
end
