class Admin::PagesController < Admin::AdminController
  layout 'admin'

  def index
    @known_pages = ["about_mynews", "newshunts", "help_faq_group", "groups", "photos"]
  end

  def edit_page
    template_name = params[:page]
    pkv = PersistentKeyValuePair.find(:first, :conditions => {"persistent_key_value_pairs.key" => "#{template_name}_template"})
    @page_template = pkv ? pkv.value : ""
  end

  def update_page
    template_name = params[:page]
    pkv = PersistentKeyValuePair.find_or_create_by_key("#{template_name}_template")
    pkv.update_attribute("value", params["template_content"])
    # Map "local-sites_environment_about"        to :section => "local_sites", :path => ["environment", "about"]
    # Map "local-sites_new-orleans_about-city" to :section => "local_sites", :path => ["new_orleans", "about_city"]
    section, *path = template_name.split("_").each { |s| s.gsub!("-", "_")}
    redirect_to page_path(:section => section, :path => path)
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Got exception trying to update template #{template_name}; section is #{section}; path is #{path.inspect}; Exception is #{e}; #{e.backtrace.inspect}"
    flash[:error] = "Got error updating static page: #{template_name}.  Logged details in the error logs.  Please let the developers know."
    redirect_to :action => :index
  end
end
