class Admin::FeedsController < Admin::AdminController
  before_filter :find_feed, :except => [:new, :index, :create, :fetch_now ]
  grant_access_to :editor
  layout 'admin'

  include StoriesHelper

  # GET /admin/feeds/
  def index
    @feeds = Feed.paginate(:all, pagination_params.merge({:total_entries => Feed.count, :conditions => ["feed_type IS NULL OR feed_type NOT IN (?)", [Feed::FB_UserStream, Feed::TW_UserNewsFeed]], :order => "id DESC", :per_page => 50}))
  end

  # GET /admin/feeds/new
  def new
    @feed = Feed.new
  end

  # GET /admin/feeds/1/test
  # Useful for testing whether the feed is valid by trying to
  # fetch stories from the feed -- but not actually update the db
  def test
    @entries = @feed.test
  rescue Exception => e
    flash[:error] = e.message
    redirect_to(admin_feeds_url)
  end

  def fetch_now
    Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:feeds:fetch_feed feed_id=#{params[:id]} submitter_id=#{current_member.id}"
    flash[:notice] = "Feed #{params[:id]} has been queued.  You will receive an email (very likely within the next 5 minutes) at #{current_member.email} once the feed has been fetched.  The email will have directions for processing the stories further if you so desire."

    referer = request.env['HTTP_REFERER']
    page_param = $1 if referer && referer =~ /(\?page=\d+)/
    redirect_to admin_feeds_url + (page_param ? page_param : "")
  end

  # POST /admin/feeds/
  def create
    cleanup_feed_params(params[:feed])
    @feed = Feed.new(params[:feed])
    @feed.save!
    flash[:notice] = "Feed #{@feed.id} created"
    Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
#    redirect_to(admin_feeds_url) # Dont redirecto feeds index!
    redirect_to(new_admin_feed_url)
  rescue ActiveRecord::RecordInvalid => e
    if params[:feed][:url].blank?
      flash[:error] = "The URL field is empty!" 
    else
      f = Feed.find_by_url(params[:feed][:url])
      flash[:error] = "There is another feed #{f.id}: #{f.name} with this url #{f.url}.  Please provide a different feed url."
    end
    redirect_to :action => "new"
  end

  def edit_stories
    num_days = (params[:timespan] || 1).to_i
    find_opts = {:joins => "JOIN story_feeds ON stories.id = story_feeds.story_id AND story_feeds.feed_id = #{@feed.id}",
                 :order => "stories.id DESC"}
    pending_stories = Story.find(:all, find_opts.merge({:conditions => ["status = 'pending' AND created_at > ?", Time.now - num_days.days]}))
    queued_stories  = Story.find(:all, find_opts.merge({:conditions => ["status = 'queue' AND created_at > ?", Time.now - num_days.days]}))
    @stories = queued_stories + pending_stories
  end

  def update_stories
    flash[:notice] = mass_update_stories(params[:stories])
    redirect_to(admin_feeds_url)
  end

  # GET /admin/feeds/1/edit
  def edit
    session[:return_to] = request.env["HTTP_REFERER"]
  end

  # PUT /admin/feeds/1
  def update
    cleanup_feed_params(params[:feed])
    @feed.update_attributes!(params[:feed])
    flash[:notice] = "Feed Updated"
    Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
    redirect_back_or_default(admin_feeds_url)
  rescue ActiveRecord::RecordInvalid => e
    if params[:feed][:url].blank?
      flash[:error] = "The URL field is empty!" 
    else
      f = Feed.find_by_url(params[:feed][:url])
      flash[:error] = "There is #{link_to "another feed", f} with id #{f.id} with this url #{f.url}.  Please provide a different feed url."
    end
    redirect_to(edit_admin_feed_url, :id => @feed.id)
  rescue Exception => e
    flash[:error] = "Error updating feed! Got exception #{e}"
    redirect_to(edit_admin_feed_url, :id => @feed.id)
  end

  # DELETE /admin/feeds/1
  def destroy
    if @feed.destroy
      flash[:notice] = "Feed Removed"
      redirect_to(admin_feeds_url)
    end
  end

  protected
  def find_feed
    @feed = Feed.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to(admin_feeds_url)
  end

  def cleanup_feed_params(f)
    f[:home_page].strip! if f[:home_page]

    if !f[:url].blank?
      f[:url].strip!
      f[:url].gsub!("feed://", "http://") # Sometimes editors like to add "feed://"
    end

      # Scrape the home page / feed and update feed attributes
    begin
      fp = FeedHelpers.update_feed_attributes :url => f[:url], :home_page => f[:home_page], :name => f[:name], :desc => f[:imported_desc]
      f[:url], f[:home_page], f[:name], f[:imported_desc] = fp[:url], fp[:home_page], fp[:name], fp[:desc]
    rescue Exception => e
      flash[:error] = e.to_s
      flash[:error] = "Could not initialize url from the home page url!  If the homepage url is valid, enter a rss feed url manually"  if f[:url].blank?
    end

    if f[:default_stype]
      f[:default_stype].strip!
      f[:default_stype].downcase!
    end

      # Truncate feed level between -100 & 100
    if f[:feed_level]
      f[:feed_level] = 100 if f[:feed_level].to_i > 100
      f[:feed_level] = -100 if f[:feed_level].to_i < -100
    end

      # Find source by name & replace name by source id
    src_input = f[:source_profile_id]
    if !src_input.blank?
      src_input.strip!
      src = Source.find_by_name(src_input) || Source.find_by_id(src_input)
      if src.nil?
        flash[:error] = (flash[:error] || "") + "Ignored source profile: Could not find source by name or id '#{src_input}'"
        f.delete(:source_profile_id)
      else
        f[:source_profile_id] = src.id
      end
    end

      # Find member by name & replace name by member id
    mem_input = f[:member_profile_id]
    if !mem_input.blank?
      mem_input.strip!
      m = Member.find_by_name(mem_input) || Source.find_by_id(mem_input)
      if m.nil?
        flash[:error] = (flash[:error] || "") + "Ignored member profile: Could not find member by name or id '#{mem_input}'"
        f.delete(:member_profile_id)
      else
        f[:member_profile_id] = m.id
      end
    end
  end
end
