# This controller handles the login/logout function of the site.
#
class SessionsController < ApplicationController
  include SessionsHelper
  include OpenidProfilesHelper

  APP_NAME = SocialNewsConfig["app"]["name"]

  before_filter :bots_not_allowed

  # render new.rhtml
  def new
    store_referer_location
    if logged_in?
      flash[:notice] = "You are logged into #{APP_NAME}."
      redirect_back_or_default(home_url)
    else
      render :layout => "popup" if params[:popup]
    end
  end
  
  # GET /sessions
  def show
    redirect_to home_url
  end
  
  def normal_create
    store_location if params[:reload]
    password_authentication(params[:email], params[:password])
  end

  def destroy
    delete_session
    target_url = params[:return_to]
    target_url = home_url if target_url.blank?
    flash[:notice] = "You have been logged out."
    redirect_back_or_default(target_url)
  end
  
  def forgot_password
    render :layout => "popup" if params[:popup]
  end
  
  def reset_password
    @pass = Member.reset_password(params)
    if @pass
      flash[:notice] = "Your temporary password has been mailed to #{params[:email]}"
      
      Mailer.deliver_reset_password(
        :from => SocialNewsConfig["email_addrs"]["help"],
        :subject => "#{APP_NAME} Password Reset",
        :recipients => params[:email],
        :body => { :pass => @pass }
      )
      
      redirect_to new_sessions_path
    else
      render :template => 'sessions/forgot_password'
    end
  rescue RuntimeError => e
    flash[:error] = "There was an error resetting your password"
    redirect_to forgot_password_sessions_path
  rescue Member::AccountSuspended => e
    flash[:error] = "The member account with email #{params[:email]} has been suspended.<br>
      Please write to #{SocialNewsConfig["email_addrs"]["help"]} to find out more."
    redirect_to forgot_password_sessions_path
  rescue ArgumentError => e
    flash[:error] = "You must specify an email address"
    redirect_to forgot_password_sessions_path
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No account matched that email address"
    redirect_to forgot_password_sessions_path
  end
  
  def resending_activation
    @member = Member.find_by_email(params[:email])
    raise ActiveRecord::RecordNotFound unless @member
    unless @member.active?
        # Generate activation code if it is nil -- for example this happens for members who signed up before October 2008.
      @member.make_activation_code if (@member.activation_code.nil?)
      Mailer.deliver_signup_notification(@member)
      flash[:notice] = "We resent your activation to \"#{@member.email}\""
    else
      flash[:notice] = "Your account is already active."
    end
    redirect_to resend_activation_sessions_path
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "No account matched that email address"
    redirect_to resend_activation_sessions_path
  end

  private
  def password_authentication(name_or_email, password)
    self.current_member = Member.authenticate(name_or_email, password)
    if logged_in?
      if params[:remember_me] == "1"
        current_member.remember_me unless current_member.remember_token?
        cookies[:auth_token] = { 
          :value => self.current_member.remember_token , :expires => self.current_member.remember_token_expires_at }
      end
      if (current_member.password_reset)
        current_member.update_attribute(:password_reset, false)
        flash[:notice] = "You've logged in the first time after your password was automatically reset.<br> Please change your password to something more memorable to you."
        redirect_to "/members/my_account#account"
      else
        respond_to do |format|
            # Regular website login
          format.html {successful_login}
            # Toolbar login (also detect scenario where there are duplicate reviews!)
          format.js { flash.discard  # So that the message is not displayed again when the member visits some page on the site
                      next_form = session[:dupe_reviews].blank? ? :review : :dupe_reviews
                      render :json => { :go                => next_form,
                                        :form_transition   => {:from => :review, :to => next_form},
                                        :notice            => session[:dupe_reviews].blank? ? nil : flash[:error],
                                        :force_form_reload => true }.to_json }
        end
      end
    else
      respond_to do |format|
        format.html {failed_login('Invalid login or password', (params[:popup] ? {:layout => "popup"} : {}))}
        format.js {render :json => {:error_message => "Invalid login or password"}.to_json}
      end
    end
  end
end
