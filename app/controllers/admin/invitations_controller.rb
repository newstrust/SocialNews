class Admin::InvitationsController < Admin::AdminController
  # By default, all hosts get access to the invitation pages so that we can grant hosts access to index, edit, and update actions
  # * Some actions require staff access
  grant_access_to :host
  before_filter :check_staff_access, :except => [:edit, :update, :index]
  before_filter :find_partner
  before_filter :find_invitation, :only => [:show, :edit, :update, :destroy, :make_primary]
  before_filter(:only => [:edit, :update]) { |controller| controller.send(:check_edit_access, :staff) }
  layout 'admin'

  APP_NAME = SocialNewsConfig["app"]["name"]
  
  def index
    @invitations = @partner.invitations.paginate(:all, pagination_params)
  end
  
  def new
    @invitation = @partner.invitations.build(:email_from => SocialNewsConfig["email_addrs"]["registrations"],
    :email_subject => "Activate your #{APP_NAME} Account",
    :invite_message => render_to_string(:partial => 'mailer/invitation_email_template'))
  end
  
  def create
    @invitation = @partner.invitations.build(params[:invitation])
    respond_to do |format|
      if @invitation.save
        @invitation.update_additional_signup_fields(params[:optional_fields]) if params[:optional_fields]
          # Set the invite as the primary invite for the partner if it is the only one!
        @partner.primary_invite = @invitation if (@partner.reload.invitations.length == 1)
        flash[:notice] = "Invitation Created"
        format.html { redirect_to(admin_partner_invitation_path(@partner, @invitation)) }
      else
        format.html { render :template => 'admin/invitations/new' }
      end
    end
  end

  def make_primary
    @partner.primary_invite = @invitation
    redirect_to admin_partner_path(@partner)
  end

  def edit
    @optional_fields = @invitation.additional_signup_fields_to_struct
  end

  def update
    respond_to do |format|
      if @invitation.update_attributes(params[:invitation])
        @invitation.update_additional_signup_fields(params[:optional_fields]) if params[:optional_fields]
        @invitation.reload # we need to reload here to ensure the friendly_id is updated.
        flash[:notice] = "Invitation Updated"
        format.html { redirect_to(edit_admin_partner_invitation_path(@partner, @invitation))}
      else
        format.html { render :template => 'admin/invitations/edit' }
      end
    end
  end

  def destroy
    respond_to do |format|
      is_primary = @partner.is_primary_invite(@invitation)
      if @invitation.destroy
        flash[:notice] = "Invitation Deleted" 
        @partner.primary_invite = @partner.invitations.find(:first) if (is_primary)
      else
        flash[:error] = "Invitation could not be deleted." 
      end
      format.html { redirect_to(admin_partner_invitations_path(@partner))}
    end
  end
    
  def find_invitation
    @invitation = @partner.invitations.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_partner_invitations_path(@partner)
  end
  
  def find_partner
    @partner = Partner.find(params[:partner_id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_partners_path
  end
end
