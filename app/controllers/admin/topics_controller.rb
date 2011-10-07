class Admin::TopicsController < Admin::LandingPageController
  include Admin::LayoutHelper
  # By default, all hosts get access to the topics page
  # But, some actions require admin access
  grant_access_to :host
  before_filter :check_admin_access, :except => [:index, :search, :layout, :update_layout, :edit, :update]
  before_filter :find_topic, :except => [:index, :new, :create, :search]
  
  layout 'admin'
  
  # GET /admin/topics.html
  def index
    @topics = Topic.paginate(:all, pagination_params.merge(:conditions => {:type => nil, :local_site_id => @local_site ? @local_site.id : nil}))
  end

  # GET /admin/topics/new.html
  def new
    @topic = Topic.new
    # Default new topic description
    @topic.intro = "How are the local news media covering this topic in #{@local_site.name}?" if @local_site
    @topic_subjects = @topic.subjects_to_struct
  end

  # POST /admin/topics.html
  def create
    # Create a new topic with passed in params
    @topic = Topic.new(params[:topic])
    @topic.local_site = @local_site
    update_image(@topic, params)
    respond_to do |format|
      if @topic.save
        @topic.subjects.update(params[:topic_subjects]) if params[:topic_subjects]
        @topic.image.save if @topic.image

        if @local_site && params[:clone_to_national]
          # Clone topic to national site
          begin
            @topic.clone_to_site(nil)
          rescue Exception => e
            logger.error "While cloning topic #{@topic.id} to national site, caught exception #{e}. #{e.backtrace.inspect}"
            flash[:error] = "Error cloning topic to national site. Error has been logged. Please ask developers to take a look at the logs."
          end
          flash[:notice] = "Topic created and cloned to national site as well"
        elsif @local_site.nil? && params[:clone_to_local_sites]
          # Clone topic to all local  site
          LocalSite.find(:all).each { |ls|
            begin
              @topic.clone_to_site(ls)
            rescue Exception => e
              logger.error "While cloning topic #{@topic.id} to local site #{ls.id}, caught exception #{e}. #{e.backtrace.inspect}"
              flash[:error] ||= ""
              flash[:error] += "Error cloning topic to local site #{ls.name}. Error has been logged. Please ask developers to take a look at the logs.<br/>"
            end
          }
          flash[:notice] = "Topic created and cloned to all local sites as well"
        else
          flash[:notice] = "Topic created"
        end
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        format.html { redirect_to admin_topic_path(@topic) }
      else
        @topic_subjects = @topic.subjects_to_struct
        format.html { render :action => "new" }
      end
    end
  end
  
  # GET/admin/sources/search
  def search
    params[:id] = params[:q] if params[:q] # Autocomplete plugin uses q as a param but we want id
    @results = []
    @results = Topic.search(params[:id]).compact  unless empty_query?
    respond_to do |format|
      format.js do
        render :json => @results.reject { |r| r.local_site != @local_site}.map {|x| "#{x.name}||#{x.slug}" }.compact.join("\n").to_json
      end
    end
  end
 
  # GET /admin/topics/some-topic/edit.html
  def edit
    # Default new topic description
    @topic.intro = "How are the local news media covering #{@topic.name} in #{@local_site.name}?" if @local_site && @topic.intro.blank?
    @topic_subjects = @topic.subjects_to_struct
  end
  
  # PUT /admin/topics/some-topic.html
  def update
    respond_to do |format|
      # Process topic image parameters
      update_image(@topic, params)

      # Check if we are renaming and there is a topic or tag by the new name
      if params[:topic][:name] != @topic.name
        existing_topic = Topic.find_by_name(params[:topic][:name], :conditions => {:local_site_id => @local_site ? @local_site.id : nil})
        renamed_existing_tag = Tag.find_by_name(params[:topic][:name])
      end

        # Check if we are trying to change topic name to another existing topic/subject!
      if existing_topic && (existing_topic.id != @topic.id)
        flash[:error] = "There is another topic/subject with the new name #{existing.name}.  Topic not updated.  Rejecting name change."
        @topic_subjects = @topic.subjects_to_struct
        format.html { render :template => 'admin/topics/edit' }
      else
        if renamed_existing_tag && renamed_existing_tag.id != @topic.tag_id
          old_tag = @topic.tag

          # We are trying to change topic name to that of another existing tag.
          # For all stories that have been tagged with 'old_tag' but not with 'renamed_existing_tag', create a new tagging 
          # for 'renamed_existing_tag' for that story
          to_retag = old_tag.taggings - renamed_existing_tag.taggings
          to_retag = to_retag & @local_site.constraint.taggings if @local_site
          to_retag.each { |t|
            begin
              renamed_existing_tag.taggings << Tagging.new(:taggable_id => t.taggable_id, :taggable_type => t.taggable_type, :member_id => t.member_id) 
            rescue Exception
              # Ignore the occasional duplicate taggings which can sneak in because of differences in member_id in taggings.
              # If I want to avoid this hassle, strictly, I have to collect taggable_ids in to_retag and use those.
              # But, I want to preserve member_id when I migrate taggings over -- hence this crude approach
            end
          }

          flash[:notice] = "Tagged #{to_retag.size} stories with the renamed topic!"
        end

          # Now try to update topic!
        if @topic.update_attributes(params[:topic])
          @topic.subjects.update(params[:topic_subjects]) if params[:topic_subjects]
          flash[:notice] = "Topic Updated" if flash[:notice].blank?
          Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
          format.html { redirect_to(edit_admin_topic_path(@topic))}
        else
          format.html { render :template => 'admin/topics/edit' }
        end
      end
    end
  end

  # DELETE /admin/topics/some-topic.html
  def destroy
    respond_to do |format|
      t = @topic.tag
      if @topic.destroy
        # if no more topics reference the underlying tag, reset that tag to being a regular tag
        t.update_attribute(:tag_type, nil) if !Topic.exists?(:tag_id => t.id)

        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        flash[:notice] = "Topic Deleted" 
      else
        flash[:error] = "Topic could not be deleted." 
      end
      format.html { redirect_to(admin_topics_path)}
    end
  end
  
  def destroy_image
    respond_to do |format|
      if @topic.image.destroy
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        flash[:notice] = "Topic's Image Deleted" 
      else
        flash[:error] = "Topic's Image could not be deleted." 
      end
      format.html { redirect_to(edit_admin_topic_path(@topic))}
    end
  end

  def layout
    load_landing_page_layout_settings(@topic)
    @tag = @topic
    render :template => 'admin/topics/layout'
  end

  def update_layout
    update_landing_page_layout(@topic)
    redirect_to topic_path(@topic)
  end

  protected
  def find_topic
    @topic = params[:id].to_i.zero? ? Topic.find_topic(params[:id], @local_site) : Topic.find(params[:id])
    raise ActiveRecord::RecordNotFound if @topic.nil? || (@topic.local_site != @local_site)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_topics_path
  end
end
