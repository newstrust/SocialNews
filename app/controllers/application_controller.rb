# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include ApplicationHelper
  helper :all # include all helpers, all the time

  include AuthenticatedSystem
  # include RoleSystem

  APP_NAME = SocialNewsConfig["app"]["name"]

  before_filter :set_active_local_site
  before_filter :password_protected # this filter should run after the previous filter sets the active local site
  
  # Used by the RoleSystem to find the current member (if any)
  # This before filter needs to be called BEFORE any role checking.
  before_filter { |controller| controller.role_player = :current_member }

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery
  
  # don't bother storing sessions for bots
  # see http://www.jroller.com/obie/entry/wrestling_with_the_bots
  session :off, :if => proc { |request| request.user_agent =~ /(Baidu|bot|Google|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)/i }
  
  # Collect or define the default params needed to paginate
  def pagination_params(opts = {})
    { :page => params[:page] || 1, :per_page => params[:per_page] || 10 }.merge(opts)
  end
  
  def empty_query?
    unless (params[:id] and params[:id].rstrip != '') || (params[:q] and params[:q].rstrip != '')
      return true
    end
    return false
  end
  
  # for creation/updates in MembersController, StoriesController, SourcesController
  def last_edited_params
    {:last_edited_at => Time.now, :edited_by_member => current_member || Member.nt_anonymous }
  end

  def get_cached_fragment_name(name = nil, base_name = "")
      # If we've been given a name, use it.  If not construct one from the params
    if !name.blank?
      cfn = name
    else
      cfn = (params.keys - ["action","controller","method","ref"]).inject(base_name) { |n,k|
              (k.blank? || params[k].blank? || k =~ /^utm_/) ? n : n + "__#{k}=#{params[k].gsub('/', '.')}"
            }
    end

      # Different cached fragments for editors, non-editors, and bots!
    cfn = "EDITOR." + cfn if editor_logged_in?
    cfn = "BOT." + cfn if visitor_is_bot?
      # Differentiate caching by local site
    cfn = @local_site.slug + ".#{cfn}" if @local_site
    cfn
  end
  
  # see http://henrik.nyh.se/2008/07/rails-404
  def render_optional_error_file(status_code)
    if status_code == :not_found
      render_404 and return
    else
      super
    end
  end
  def render_404
    render_error_by_code(404)
  end
  def render_403(model_class,message = "")
    @model_class_name = (model_class.class == Class) ? model_class.name.downcase : model_class
    @no_bots = true
    @message = message
    render_error_by_code(403)
  end
  def render_error_by_code(code)
    respond_to do |type| 
      type.html { render :template => "errors/#{code.to_s}", :status => code } 
      type.all  { render :nothing => true, :status => code }
    end
    true  # so we can do "render_404 and return"
  end
  # alias_method :rescue_action_locally, :rescue_action_in_public # for development ONLY

  def bots_not_allowed
    render_403('page') if visitor_is_bot?
  end

  # SSS: Turn off all ip spoofing checks for now -- as per patch in config/rails_patches.rb
  @@ip_spoofing_check = false
  
  def render_flash(custom_flash = nil)
    message = custom_flash || flash
    flash_types = [:error, :warning, :notice]
    flash_type = flash_types.detect { |a| message.keys.include?(a) }
    "<div class='flash_%s'>%s</div>" % [flash_type.to_s, message[flash_type]] if flash_type 
  end
  helper_method :render_flash

  def update_image(obj, params)
    img_params = params[:image]
    return if img_params.blank?

    otype = obj.class.name
    if !img_params[:uploaded_data].blank?  # New image
      obj.image = Image.new(img_params)
      params[otype.downcase.to_sym][:image] = obj.image if !obj.new_record?
    elsif obj.image  # Update image attrs
      obj.image.update_attributes(img_params)
    elsif !(img_params[:credit].blank? && img_params[:credit_url].blank?) && !obj.new_record?
      flash[:error] = "#{otype} has no existing image -- cannot update image credits without a corresponding image!"
    end
  end

    # SSS: Do not log routing and unknown action errors in production
    # Tip courtesy http://maintainable.com/articles/rails_logging_tips
  @@exceptions_not_logged = (RAILS_ENV == 'production') ? ['ActionController::UnknownAction', 'ActionController::RoutingError'] : []
  protected

  def password_protected
    if RAILS_ENV == "staging" || (@local_site && !@local_site.is_active?)
      authenticate_or_request_with_http_basic do |username, password|
        username == "social" && password == "news"
      end
    end
  end

  def log_error(exc)
    super unless @@exceptions_not_logged.include?(exc.class.name)
  end

  def set_active_local_site
    @referrer_url = request.env["HTTP_REFERER"].to_s
    from_subdomain = $1 if @referrer_url =~ %r|https?://([^\.:/]*)(\..*)?(:\d+)?|
    @from_local_site = LocalSite.cached_site_by_subdomain(from_subdomain)

    subdomain = params[:local] 
    subdomain = $1 if request.url =~ %r|https?://([^\.:/]*)(\..*)?(:\d+)?| if subdomain.blank?
    @local_site = LocalSite.cached_site_by_subdomain(subdomain, params)

    Mailer.setup_local_site(@local_site)
    NotificationMailer.setup_local_site(@local_site)
  end
end
