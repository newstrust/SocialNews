class Admin::SubjectsController < Admin::LandingPageController
  include Admin::LayoutHelper

  grant_access_to :host
  before_filter :check_admin_access, :except => [:edit, :update, :index, :search, :layout, :update_layout]
  before_filter :not_supported, :only => [:new, :create, :destroy]
  before_filter :find_subject, :except => [:index]
  # Only admin and subject hosts get edit & update access to the subject
  before_filter(:only => [:edit, :update]) { |controller| controller.send(:check_edit_access, :admin) }
  layout 'admin'

  # GET /admin/subjects.html
  def index
    @subjects = Subject.paginate(:all, pagination_params.merge(:conditions => {:type => 'Subject', :local_site_id => @local_site ? @local_site.id : nil}))
  end

  # GET /admin/subjects/some-subject/edit.html
  def edit
    @subject.intro = "How are the local news media covering #{@subject.name} in #{@local_site.name}?" if @local_site && @subject.intro.blank?
  end

  # PUT /admin/subjects/some-subject.html
  def update
    respond_to do |format|
      # Process subject image parameters
      update_image(@subject, params)

        # Process rest of subject parameters
      if @subject.update_attributes(params[:subject])
        flash[:notice] = "Subject Updated"
        format.html { redirect_to(edit_admin_subject_path(@subject))}
      else
        format.html { render :template => 'admin/subjects/edit' }
      end
    end
  end
  
  def destroy_image
    respond_to do |format|
      if @subject.image.destroy
        flash[:notice] = "Subject's Image Deleted" 
      else
        flash[:error] = "Subject's Image could not be deleted." 
      end
      format.html { redirect_to(edit_admin_subject_path(@subject))}
    end
  end

  def layout
    load_landing_page_layout_settings(@subject)
    @tag = @subject
    render :template => "admin/topics/layout"
  end

  def update_layout
    update_landing_page_layout(@subject)
    redirect_to subject_url(@subject)
  end
  
  protected
  def find_subject
    @subject = params[:id].to_i.zero? ? Subject.find_subject(params[:id], @local_site) : Subject.find(params[:id])
    raise ActiveRecord::RecordNotFound if @subject.local_site != @local_site
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_subjects_path
  end

  def not_supported
    raise "You cannot create/delete subjects at this time -- only edit existing subjects!"
  end
end
