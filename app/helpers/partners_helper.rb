module PartnersHelper
  def use_partner_layout
    self.class.send(:layout, 'application') # reset 
    
    @partner = Partner.find(params[:partner_id])
    @invitation = find_invitation if params[:invitation_id] && @partner
    file_name = File.join( RAILS_ROOT, 'app/views/layouts', "#{@partner.friendly_id}.html.erb")
    
    self.class.send(:layout, @partner.friendly_id) if File.exist?(file_name)
  rescue ActiveRecord::RecordNotFound
    # do nothing and use the default layout
  end
  
  def find_invitation
    @invitation = @partner.invitations.find(params[:invitation_id])
  rescue ActiveRecord::RecordNotFound
    # No need to raise here because invitations are totally optional.
  end
end
