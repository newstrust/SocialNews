class MailerController < ApplicationController
  before_filter :login_required
  
  def send_to_friend
    params[:message].merge!(:from => current_member.email, :from_name => current_member.display_name) if params[:message]
    @sent, @unsent, @undeliverable = Mailer.send_to_friend(params[:message])
    flash[:notice] = "Message Sent!" unless @sent.empty?
    flash[:warning] = "Maximum #{Mailer.recipient_limit} emails already sent." unless @unsent.empty?
    render_send_to_friend(200)
  rescue ArgumentError => e
    flash[:error] = e.message
    render_send_to_friend(406)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    render_send_to_friend(406)
  end
  
  protected
  def render_send_to_friend(status)
    respond_to do |format|
      format.js do
        render :inline => { :flash => flash.to_hash, :sent => @sent, :unsent => @unsent, :undeliverable => @undeliverable }.to_json, :status => status
        flash.discard
      end
    end
  end
end
