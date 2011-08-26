module OpenidProfilesHelper
  def create
    if using_open_id?
      open_id_authentication
    else
      normal_create
    end
  end
  
  def normal_create
    throw :normal_create_not_implemented, "Implement me in this controller!"
  end

  # Pass optional :required and :optional keys to specify what sreg fields you want.
  # Be sure to yield registration, a third argument in the #authenticate_with_open_id block.
  # REMEMBER: a "required" field is not guaranteed to be returned by OpenID provider
  def open_id_authentication
    authenticate_with_open_id(params[:openid_url], 
        :required => [ :email ],
        :optional => [ :email, :fullname ]) do |result, identity_url, registration|
      if result.successful?
        successful_openid_login(identity_url, registration)
      else
        failed_login(result.message || "Sorry could not log in with identity URL: #{identity_url}")
      end
    end
  rescue OpenIdAuthentication::InvalidOpenId => e
    failed_login(e.message)
  end

private
  def successful_openid_login(identity_url, registration = {})
    unless @completed_member = (@member = Member.find_by_identity_url(identity_url))
      @member = Member.new(:identity_url => identity_url)
      assign_registration_attributes(identity_url, registration)
    end
    
    if @completed_member
      self.current_member = @completed_member
      successful_login
    else
      unfinished_registration(identity_url)
    end
  end
  
  # registration is a hash containing the valid sreg keys given above
  # use this to map them to fields of your member model
  def assign_registration_attributes(identity_url, registration)
    { 
      :login  => 'nickname', 
      :email  => 'email', 
      :name   => 'fullname' 
    }.each do |model_attribute, registration_attribute|
      unless registration[registration_attribute].blank?
        @member.send("#{model_attribute}=", registration[registration_attribute])
      end
    end
    # CHOOSE - Uncomment to clean up logins as desired for application; 
    #          else login = nickname, e.g. "Dr Nic" instead of 'drnic'
    # @member.login.gsub!(/\W+/,'').downcase unless @member.login.blank?
    @member.identity_url = identity_url
    @completed_member = Member.find_or_create_by_openid_params(@member)
  end
  
  def successful_login
    flash[:notice] = "Logged in successfully"
    redirect_back_or_default('/')
  end
  
  def unfinished_registration(identity_url)
    redirect_to new_member_path(:member => { :identity_url => identity_url }.merge(@member.attributes))
    flash[:warning] = "Your openid did not contain all of the required fields; please complete your registration."
  end
  
  def failed_login(message, render_options={})
    flash.now[:error] = message
    render(render_options.merge(:action => 'new'))
  end
end
