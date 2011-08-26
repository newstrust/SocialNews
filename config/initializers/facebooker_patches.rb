# Facebooker expects this method in Array -- probably present in a later version of rails.
class Array
  def second
    (self.length > 1) ? self[1] : nil
  end
end

module Facebooker
  module Rails
    module Helpers
      module FbConnect
          # SSS HACKS! 
          # 1. Facebooker assumes prototype! post-process it to use jquery's equivalent hander
          #
          #	2. As per: http://wiki.developers.facebook.com/index.php/Detecting_Connect_Status,
          #	   if the facebook connect status changes, reload the page to ensure that the latest
          #	   status is reflected since the new status is not available till after the page loads.
          #		 Without the reload, the current page load will have stale status information.
          #
          #		 Facebooker doesn't give you a way of passing in this extra param -- so hack it!

        def init_fb_connect_FIXED_UP(no_auto_reload = nil, auto_login = false)
          # If the reload_page param hasn't been passed in, reload page only if we are not trying to log out!
          reload_page = no_auto_reload.nil? ? @fb_logout_redirect_url.nil? : !no_auto_reload
          app_settings_string  = reload_page ? "'reloadIfSessionStateChanged': true" : ""
          app_settings_string += "#{reload_page ? ', ' : ''}'ifUserConnected': fbc_login" if auto_login
          init_fb_connect("XFBML", "Api", {:js => :jquery, :app_settings => "{#{app_settings_string}}"}) {
            buf = ""
              # Publish any pending publishable actions
            buf += fb_user_action(@fb_user_action) if @fb_user_action
              # Logout the user if that is what has been requested!
            buf += fb_logout(@fb_logout_redirect_url) if @fb_logout_redirect_url
            buf
          }
        end
      end

      def fb_logout(url)
        update_page do |page|
          page.call "FB.Connect.logoutAndRedirect", url
        end
      end

      def fb_logout_link(text, url)
        link_to_function text, fb_logout(url)
      end

      # Request signature is computed as per procedure describe in page below: 
      # http://wiki.developers.facebook.com/index.php/How_Facebook_Authenticates_Your_Application

      require 'digest/md5'
      def fb_get_request_sig(args)
          # Sort argument array alphabetically by key, then append everything as "k=v", except the signature itself (obviously)
        arg_str = args.sort {|x,y| x[0] <=> y[0] }.inject("") { |buf,a| buf + (a[0] == "req_sig" ? "" : "#{a[0]}=#{a[1]}") }

          # Append the secret key and compute the md5 hash of the string
        Digest::MD5.hexdigest(args_str + Facebooker.secret_key)
      end
    end
  end
end
