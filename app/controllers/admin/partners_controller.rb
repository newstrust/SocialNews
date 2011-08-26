class Admin::PartnersController < Admin::AdminController
  before_filter :find_partner, :only => [:show, :edit, :update, :destroy]
  layout 'admin'
  def index
    # Find the membership groups
    @partners = Partner.paginate(:all, pagination_params)
  end
  
  def new
    @partner = Partner.new
  end
  
  def create
    @partner = Partner.create(params[:partner])
    respond_to do |format|
      if @partner.valid?
        flash[:notice] = "Partner Created" 
        format.html { redirect_to(admin_partner_path(@partner)) }
      else
        format.html { render :template => 'new' }
      end
    end
  end
  
  def update
    @partner.update_attributes(params[:partner])    
    respond_to do |format|
      if @partner.valid?
        flash[:notice] = "Partner Updated" 
        format.html { redirect_to(edit_admin_partner_path(@partner)) }
      else
        format.html { render :template => 'edit' }
      end
    end
  end
  
  def destroy
    respond_to do |format|
      if @partner.destroy
        flash[:notice] = "Partner Destroyed"
        format.html { redirect_to(admin_partners_path) }
      else
        flash[:error]= @partner.errors.full_messages.join('<br/>')
        format.html { redirect_to(edit_admin_partner_path(@partner)) }
      end
    end
  end

  protected
  
  def find_partner
    @partner = Partner.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_partners_path
  end
end
