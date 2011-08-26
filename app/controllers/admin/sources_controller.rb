class Admin::SourcesController < Admin::AdminController
  before_filter :find_source, :except => [:search, :index, :new, :create, :pending, :listed, :hidden, :featured, :merge_tool, :merge]
  layout 'admin'
  
  # GET /admin/sources.html
  def index
    @title = "Sources"
    @sources = Source.paginate(:all, pagination_params)
  end
  
  def pending
    @title = "Pending Sources"
    @sources = Source.paginate(:all, pagination_params.merge(:conditions => "status = 'pending'"))
    respond_to do |format|
      format.html { render :action => :index }
    end
  end

  def hidden
    @title = "Hidden Sources"
    @sources = Source.paginate(:all, pagination_params.merge(:conditions => "status = 'hide'"))
    respond_to do |format|
      format.html { render :action => :index }
    end
  end

  def listed
    @title = "Listed Sources"
    @sources = Source.paginate(:all, pagination_params.merge(:conditions => "status = 'list'"))
    respond_to do |format|
      format.html { render :action => :index }
    end
  end
  
  def featured
    @title = "Featured Sources"
    @sources = Source.paginate(:all, pagination_params.merge(:conditions => "status = 'feature'"))
    respond_to do |format|
      format.html { render :action => :index }
    end
  end

  # GET/admin/sources/search
  def search
    params[:id] = params[:q] if params[:q] # Autocomplete plugin uses q as a param but we want id
    @results = []
    @results = Source.search(params[:id])  unless empty_query?
    respond_to do |format|
      format.js do
        render :json => @results.compact.map {|x| "#{x.name}|#{x.status}|#{x.slug}|#{x.id}" }.compact.join("\n").to_json
      end
    end
  end
  
  # GET /admin/sources/new.html
  def new
    @source = Source.new
  end
    
  # POST /admin/sources.html
  def create
    @source = Source.new(params[:source].merge!(:edited_by_member_id => current_member.id, :last_edited_at => Time.now))
    update_image(@source, params)
    respond_to do |format|
      if @source.save
        flash[:notice] = "Source Created"
        if @source.source_media.blank?
          @source.source_media << SourceMedium.new(:medium => SourceMedium::OTHER, :main => true)
          flash[:notice] += ".  The source medium is set to #{SourceMedium::OTHER}.  Please update this field when you edit this source."
        end
        @source.image.save if @source.image
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        format.html { redirect_to admin_source_path(@source) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  # PUT /admin/sources/some-source.html
  def update
    respond_to do |format|
      update_image(@source, params)
      params[:source].merge!(:edited_by_member_id => current_member.id, :last_edited_at => Time.now)
      if @source.update_attributes(params[:source])
        flash[:notice] = "Source Updated"
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        format.html { redirect_to(edit_admin_source_path(@source))}
      else
        format.html { render :template => 'admin/sources/edit' }
      end
    end
  end
  
  # DELETE /admin/sources/some-source.html
  def destroy
    respond_to do |format|
      if @source.destroy
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        flash[:notice] = "Source Deleted" 
      else
        flash[:error] = "Source #{@source.id} has stories assigned to it.  Cannot delete the source till all those stories are re-assigned / deleted."
      end
      format.html { redirect_to(admin_sources_path)}
    end
  end

  # POST /admin/sources/merge
  #
  # This merges several source objects into a target source.
  def merge
    keep_id = params[:keep_id].to_i
      # Accept commas or spaces as separators
    merge_ids = params[:merge_ids].gsub(/,/, " ").split.collect { |x| x.to_i }
    if (merge_ids.include?(keep_id))
      flash[:error] = "#{keep_id} is present in the merge list too -- you cannot merge a source with itself!  That would be like a snake eating its tail, and would lead to the end of this world!  Please verify your source ids and try again!"
      flash.discard
      render :action => 'merge_tool'
    else
      begin
          # Load the objects
        @keep = Source.find(keep_id)
        @hide = merge_ids.collect { |id| Source.find(id) }

          # Merge!
        @keep.swallow_dupes(@hide)

          # Reload the @keep object
        @keep = Source.find(keep_id)

        flash[:notice] = "Merged sources #{merge_ids * ", "} into source #{keep_id}."
        flash[:notice] += "<br> Note that the source you decided to retain (#{keep_id}) is a hidden source." if (@keep.status == 'hide')
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        flash.discard
      rescue ActiveRecord::RecordNotFound => e
        flash[:error] = e.to_s
        flash.discard
        render :action => 'merge_tool'
      end
    end
  end

  # DELETE /admin/sources/some-source/destroy_image.html
  def destroy_image
    respond_to do |format|
      if @source.image.destroy
        Bj.submit "rake RAILS_ENV=#{RAILS_ENV} socialnews:gen_taxonomies"  # regenerate taxonomies
        flash[:notice] = "Source's Image Deleted" 
      else
        flash[:error] = "Source's Image could not be deleted." 
      end
      format.html { redirect_to(edit_admin_source_path(@source)) }
    end
  end

  protected
  def find_source
    @source = Source.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_sources_path
  end
end
