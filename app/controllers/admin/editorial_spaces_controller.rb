class Admin::EditorialSpacesController < Admin::AdminController
  layout 'admin'

  include Admin::LandingPageHelper

  # GET /editorial_spaces/new
  # GET /editorial_spaces/new.xml
  def new
    @editorial_space = EditorialSpace.new
    @editorial_space.local_site = use_site_specific_layout?(params[:page_type]) && @local_site ? @local_site : nil
    @editorial_space.page = params[:page_id] && params[:page_type] ? params[:page_type].capitalize.constantize.send(:find, params[:page_id]) : nil

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @editorial_space }
    end
  end

  # GET /editorial_spaces/1/edit
  def edit
    @editorial_space = EditorialSpace.find(params[:id])
  end

  # POST /editorial_spaces
  # POST /editorial_spaces.xml
  def create
    opts = params[:editorial_space] || {}

    # set page type & id params to nil if they are blank.  Otherwise, will crash.
    params[:page_type] = nil if params[:page_type].blank?
    params[:page_id] = nil if params[:page_id].blank?

    ls_id = use_site_specific_layout?(params[:page_type]) && @local_site ? @local_site.id : nil
    @editorial_space = EditorialSpace.create(opts.merge!(:context => 'right_column', :local_site_id => ls_id, :page_id => params[:page_id], :page_type => params[:page_type]))
    if @editorial_space
      page = @editorial_space.page
      redirect_to page ? page_layout_path(:page_id => page.id, :page_type => page.class.name) : admin_home_path
    else
      render :action => "new"
    end
  end

  # PUT /editorial_spaces/1
  # PUT /editorial_spaces/1.xml
  def update
    @editorial_space = EditorialSpace.find(params[:id])
    if @editorial_space.update_attributes(params[:editorial_space])
      page = @editorial_space.page
      redirect_to page ? page_layout_path(:page_id => page.id, :page_type => page.class.name) : admin_home_path
    else
      render :action => "edit"
    end
  end

  # DELETE /editorial_spaces/1
  # DELETE /editorial_spaces/1.xml
  def destroy
    @editorial_space = EditorialSpace.find(params[:id])
    page = @editorial_space.page
    @editorial_space.destroy
    redirect_to page ? page_layout_path(:page_id => page.id, :page_type => page.class.name) : admin_home_path
  end
end
