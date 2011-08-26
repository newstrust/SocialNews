if !defined?(SocialNewsConfig)
  # Make sure this works when used in plain ruby context rather than a rails context
  require "rubygems"
  require "open-uri"
  require 'net/http'

  SocialNewsConfig = { "app" => { "name" => "SocialNews" } }
end

require 'system_timer'

module NetHelpers
  @@timeout_period = 30 ## Default timeout
  @@max_retries    = 5  ## Default number of attempts to fetch a url before giving up!
  @@max_redirects  = 5  ## Follow redirects at most 5 times!

      ## These are url snippets of login screens that sites throw up.  If we encounter these
      ## urls as part of title processing, don't overwrite the url!
  LOGIN_SCREEN_URL_SNIPPETS = [
    "washingtonpost.*destination=login"
  ]

  def self.set_http_timeout(n)
    @@timeout_period = n
  end

  def self.get_url_domain(url)
    return (url =~ %r|https?://(www\.)?([^/]+)/?.*$|) ? $2 : ""
  end

  def self.is_login_screen_url(url)
    LOGIN_SCREEN_URL_SNIPPETS.each { |re| return true if url =~ /#{re}/ }
    false
  end

  def self.get_response(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port) { |http| 
      remote_resource = uri.query ? (uri.path + "?" + uri.query) : uri.path
      remote_resource = "/" if remote_resource.nil? || remote_resource.empty?
        # Digg doesn't like blank user agent strings -- hence all this song and dance
      http.request(Net::HTTP::Get.new(remote_resource, { "User-Agent" => SocialNewsConfig["app"]["name"] }))
    }
  end

  def self.get_response_with_redirect_processing(url, max_retries = 5)
    uri = URI.parse(url)

      # Follow redirects as necessary, while setting cookies! (ex: NY Times)
      # For most sites that don't do the redirect dance, you will get the title in the first try
    num_redirects = 0
    resp   = nil
    cookie = nil
    while (num_redirects < max_retries)
      resp = Net::HTTP.start(uri.host, uri.port) { |http| 
        remote_resource = uri.query ? (uri.path + "?" + uri.query) : uri.path
        headers = { "User-Agent" => SocialNewsConfig["app"]["name"] }
        # Set cookie that you are given -- essential to fool the server to think you are a normal browser
        headers.merge!({ "Cookie" => cookie }) if cookie
        http.request(Net::HTTP::Get.new(remote_resource, headers))
      }

        # Follow redirects till you get a normal OK
      case resp
      when Net::HTTPMovedPermanently then
        uri = URI.parse(resp['location'])
        cookie = resp['set-cookie']
        num_redirects += 1
      when Net::HTTPFound then
        target_uri = URI.parse(resp['location'])
        uri = target_uri
        ret_cookies = resp.get_fields('set-cookie')
        cookie = ret_cookies.inject("") { |s,c| s + c.split("\; ")[0] + "\; " } if ret_cookies
        num_redirects += 1
      when Net::HTTPSuccess   then
        break
      else
        break
      end
    end

    resp
  end

  ## Fetch the html from the url
  ##  --> bad uris
  ##  --> urls from this webapp itself! 
  ##  --> timeouts
  ##  --> redirect loops with set cookies
  def self.fetch_content(url)
    begin
        # Don't lock up the server for too long!
      SystemTimer::timeout(@@timeout_period) {
        uri = URI.parse(url)

          # Follow redirects as necessary, while setting cookies! (ex: NY Times)
          # For most sites that don't do the redirect dance, you will get the title in the first try
        num_redirects = 0
        resp   = nil
        cookie = nil
        while (num_redirects < @@max_retries)
          resp = Net::HTTP.start(uri.host, uri.port) { |http| 
            remote_resource = uri.query ? (uri.path + "?" + uri.query) : uri.path
            headers = { "User-Agent" => SocialNewsConfig["app"]["name"] }
            # Set cookie that you are given -- essential to fool the server to think you are a normal browser
            headers.merge!({ "Cookie" => cookie }) if cookie
            http.request(Net::HTTP::Get.new(remote_resource, headers))
          }

            # Follow redirects till you get a normal OK
          case resp
          when Net::HTTPMovedPermanently then
            uri = URI.parse(resp['location'])
            cookie = resp['set-cookie']
            num_redirects += 1
          when Net::HTTPFound then
            target_uri = URI.parse(resp['location'])
            if (is_login_screen_url(target_uri.to_s))
              break
            else
              uri = target_uri
              ret_cookies = resp.get_fields('set-cookie')
              cookie = ret_cookies.inject("") { |s,c| s + c.split("\; ")[0] + "\; " } if ret_cookies
              num_redirects += 1
            end
          when Net::HTTPSuccess   then
            break
          else
            break
          end
        end

          # Finally, we have what we want after all that drama!
        resp.body.strip!
        [uri.to_s, resp.body]
      }
    end
  end

      ## These domains are essentially proxies for story urls.
      ## If a story url has this domain, go fetch the url and get the 'real' location!
  URL_PROXY_DOMAINS = [ "^feeds\\.", "^feedproxy\\.", "\\.feedburner.com$", "^pheedo\\.", "^washtimes.com$", "^t.co$",
                        "^tinyurl.com$", "^bit.ly$", "^is.gd$", "^cli.gs$", "^tr.im$", "^kl.am$", "^twurl.nl$", "^ginx.com$" ]

  def self.is_proxy_domain(d)
    !(URL_PROXY_DOMAINS.find { |p| d =~ /#{p}/ }).nil?
  end

  def self.get_302_target(proxy_url)
    tries = 0
    begin
        # Don't lock up the server for too long!
        # Solution courtesy http://www.ruby-forum.com/topic/77694
      SystemTimer::timeout(@@timeout_period) {
        response = NetHelpers.get_response(proxy_url)
        case response
          when Net::HTTPSuccess     then return proxy_url
          when Net::HTTPRedirection then return response['location']
        else
#          @logger.error "While getting 302 target for #{proxy_url}, got an error: #{response.error!}" 
          STDERR.puts "While getting 302 target for #{proxy_url}, got an error: #{response.error!}" 
          return proxy_url
        end
      }
    rescue Exception => e
#      @logger.error "Exception fetching response for #{proxy_url}: #{e.message} .. Retrying"
      STDERR.puts "Exception fetching response for #{proxy_url}: #{e.message} .. Retrying"
      tries += 1
      retry if tries < @@max_retries
    end

      ## We didn't succeed following this proxy url!
#    @logger.error "Failed to follow proxy story url #{proxy_url}. Giving up after #{@@max_retries} attempts!"
    STDERR.puts "Failed to follow proxy story url #{proxy_url}. Giving up after #{@@max_retries} attempts!"
    return proxy_url
  end

  def self.get_target_url(url)
      ## if the url domain is present in URL_PROXY_DOMAINS, follow the url and
      ## get the target url and return that url's domain!
    orig_url = url
    tries = 0
    while (tries < @@max_redirects)
      if (is_proxy_domain(get_url_domain(url)) || (url =~ /digg.com/ && url.length < 30))
        new_url = get_302_target(url)
          ## For those sites (like Digg) that return relative urls!
        url = (new_url !~ %r|http://|) ? "http://#{get_url_domain(url)}#{new_url}" : new_url
        tries += 1
      else
        return url
      end
    end

    raise "Story url #{orig_url} redirecting too many times. Stopped after #{@@max_redirects} redirects.  Current url is #{url}"
  end
end
