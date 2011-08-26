# This file is for patching bugs in rails code

module ActionController

  # SSS: Patch for bugs at:
  #   1. http://rails.lighthouseapp.com/projects/8994/tickets/322
  #   2. http://rails.lighthouseapp.com/projects/8994/tickets/1200
  #
  # Includes patches at 
  #   1. http://rails.lighthouseapp.com/attachments/25763/forwarded_client_ip_with_test.patch
  #   2. http://rails.lighthouseapp.com/attachments/64720/ip_spoof.diff
  #
  # and my own fix

  class Base
     # Controls the IP Spoofing check when determining the remote IP.
     @@ip_spoofing_check = true
     cattr_accessor :ip_spoofing_check
  end

  class AbstractRequest
    # Determine originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these if
    # REMOTE_ADDR is a proxy.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the last
    # address which is not trusted is the originating IP.
    def remote_ip
      if TRUSTED_PROXIES !~ @env['REMOTE_ADDR']
        return @env['REMOTE_ADDR']
      end

      remote_ips = @env['HTTP_X_FORWARDED_FOR'] && @env['HTTP_X_FORWARDED_FOR'].split(',')

      if @env.include? 'HTTP_CLIENT_IP'
        if remote_ips && !remote_ips.include?(@env['HTTP_CLIENT_IP'])
          if ActionController::Base.ip_spoofing_check 
            # We don't know which came from the proxy, and which from the user
            raise ActionControllerError.new(<<EOM)
IP spoofing attack?!
HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}
HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}
EOM
          else
              # SSS: See http://en.wikipedia.org/wiki/X-Forwarded-For
            return @env['HTTP_X_FORWARDED_FOR'][0]
          end
        end
        return @env['HTTP_CLIENT_IP']
      end

      if remote_ips
        while remote_ips.size > 1 && TRUSTED_PROXIES =~ remote_ips.last.strip
          remote_ips.pop
        end

        return remote_ips.last.strip
      end

      @env['REMOTE_ADDR']
    end
  end
end
