module AuthenticatedSystem
  protected
    # Returns true or false if the member is logged in.
    # Preloads @current_member with the member model if they're logged in.
    def logged_in?
      !!current_member
    end

    # Since this functionality is commonly used in several controllers
    def editor_logged_in?
      logged_in? and current_member.has_role_or_above?(:editor)
    end

    # Accesses the current member from the session. 
    # Future calls avoid the database because nil is not equal to false.
    def current_member
      @current_member ||= (login_from_session || login_from_basic_auth || login_from_cookie || login_from_fb) unless @current_member == false
      (@current_member && !@current_member.terminated?) ? @current_member : nil
    end

    # Store the given member id in the session.
    def current_member=(m)
      if m && !m.terminated?  # terminated members cannot login!
        @current_member = m
        session[:member_id] = m.id
        dupes = m.process_guest_actions(session[:submits], session[:reviews], session[:source_reviews])
        if !dupes.blank?
          session[:dupe_reviews] = dupes
          flash[:error] = "It appears that you reviewed the same story at least twice when you were logged off. Please #{link_to("click here now", process_dupe_reviews_members_url, :class => "error_message")} to pick the review you want to keep.  If you don't take any action, your new review will be discarded by default."
        end
        session[:reviews] = nil
        session[:source_reviews] = nil
        m
      else
        @current_member = false
        session[:member_id] = nil
        nil
      end
    end

    # Check if the member is authorized
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the member
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorized?
    #    current_member.login != "bob"
    #  end
    def authorized?
      logged_in?
    end

    # Filter method to enforce a login requirement.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_filter :login_required
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_filter :login_required, :only => [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_filter :login_required
    #
    def login_required
      authorized? || access_denied
    end

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the member is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied
      respond_to do |format|
        format.html do
          store_referer_location
          redirect_to(logged_in? ? home_path : new_sessions_path)
        end
        format.any do
          request_http_basic_authentication 'Web Password'
        end
      end
    end

    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    #
    # N.b. If this request was anything other than a plain GET, we have to throw the URL away
    # see http://rubyglasses.blogspot.com/2008/04/redirectto-post.html
    def store_location
      session[:return_to] = request.get? ? request.request_uri : request.env["HTTP_REFERER"]
    end

    # A bit like the above, but only called from login & signup pages, _not_ from 'access denied' pages.
    # Store referer location _if_ it's on our site but isn't log in or sign up pages!
    def store_referer_location
      dont_return_to_paths = [fb_logout_path, new_member_path, new_sessions_path] # a constant of sorts
      referer_uri = URI.parse(request.env["HTTP_REFERER"])
      ref_path = referer_uri.path.gsub(/\?.*/, '')
      if referer_uri.host == request.server_name and !dont_return_to_paths.include?(ref_path)
        session[:return_to] ||= referer_uri.to_s
      end
    rescue URI::InvalidURIError
      # do nothing
    end
    
    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.
    def redirect_back_or_default(default)
      target = session[:return_to] || default
      redirect_to(target)
      session[:return_to] = nil
    end

    def redirect_to_back_or_default(to_url, default)
      target = to_url || session[:return_to] || default
      redirect_to(target)
      session[:return_to] = nil
    end

    # Inclusion hook to make #current_member and #logged_in?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_member, :logged_in?
    end

    # Called from #current_member.  First attempt to login by the member id stored in the session.
    def login_from_session
      self.current_member = Member.find_by_id(session[:member_id]) if session[:member_id]
    end

    # Called from #current_member.  Now, attempt to login by basic authentication information.
    def login_from_basic_auth
      authenticate_with_http_basic do |username, password|
        self.current_member = Member.authenticate(username, password)
      end
    end

    # Called from #current_member.  Finaly, attempt to login by an expiring token in the cookie.
    def login_from_cookie
      member = cookies[:auth_token] && Member.find_by_remember_token(cookies[:auth_token])
      if member && member.remember_token?
        cookies[:auth_token] = { :value => member.remember_token, :expires => member.remember_token_expires_at }
        self.current_member = member
      end
    end

    def member_from_fb_session
      if session[:fb_uid]
        fb_uid = session[:fb_uid]
      else
        fb_user_info = FacebookConnectSettings.get_user_info_from_cookies(cookies)
        return nil if fb_user_info.nil?
     
        fb_uid       = fb_user_info["user_id"]
        session[:fb_uid] = fb_uid
        return nil if fb_uid.nil?
      end
     
      if fb_uid
        Member.find(:first, :joins => :facebook_connect_settings, 
                            :conditions => ["facebook_connect_settings.fb_uid = ?", fb_uid], 
                            :readonly => false)
      end
    end

    # Login from facebook
    def login_from_fb
      member = member_from_fb_session
      if (member && session[:member_id] && member.id != session[:member_id])
        app_name = SocialNewsConfig["app"]["name"]
        flash[:warning] = "You have been logged out of your #{Member.find_by_id(session[:member_id], :select => "email").email} #{app_name} account, and then logged into your #{member.email} #{app_name} account which is already connected to Facebook.<br/>"
      end
      if member
        self.current_member = member 
        session[:fb_activated] = true
      end
      member
    rescue Exception => e
      RAILS_DEFAULT_LOGGER.error " --------> #{e}; #{e.backtrace.inspect} <----------"
      nil
    end
end
