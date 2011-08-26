#!/usr/local/bin/ruby -w

# site_monitor.rb - monitor the status of servers & send out emails if they're not responding correctly

require 'net/http'
require 'net/smtp'
require 'uri'
require 'time'


# Class for running through tests and sending email if any fails
#
class SiteMonitor
  
  # constants
  SENDER_EMAIL_ADDRESS = "noreply@socialnews.com"
  RECIPIENT_EMAIL_ADDRESSES = [ "testing@socialnews.com" ]
  
  # CONFIG. list all URLs to test. Types correspond to sub-classes of UrlTest below.
  @@test_config = [
    { :url => "http://socialnews.com/pages/health_check", :type => :health_check },
    { :url => "http://socialnews.com/pages/bj_check", :type => :b_j_check }
  ]
  
  # set vars & begin testing process
  #
  def initialize
    @errors_or_warnings_found = false
    @email_body = Time.now.to_s + "\n\n"
    
    run_tests
    
    if @errors_or_warnings_found
      send_alert_email # send email if any tests failed
      # TODO: write out log file or do SOMETHING if email can't be sent (!!)
    end
  end
  
  # Loop through the test URLs above, generate UrlTest classes & run them
  def run_tests
    @@test_config.each do |test|
      url_test = generate_url_test(test)
      @errors_or_warnings_found |= url_test.run_tests
      @email_body += url_test.format_results
    end
  end
  
  # ruby dynamic class-wrangling
  def generate_url_test(test)
    test_class_base = "UrlTest"
    test_class = (test.has_key?(:type) ? test[:type].to_camelcase : "") + test_class_base
    begin
      url_test = self.class.const_get(test_class).new(test[:url])
    rescue
      url_test = self.class.const_get(test_class_base).new(test[:url])
    end
    return url_test
  end
  
  # now actually send the alert email
  def send_alert_email
    # they're really going to make me format the headers myself?
    email_message = 
      "From: " + SENDER_EMAIL_ADDRESS + "\n" +
      "To: " + RECIPIENT_EMAIL_ADDRESSES.join(", ") + "\n" +
      "Subject: ALERT: SocialNews failed monitor tests\n\n" + 
      @email_body + "\n"
    
    Net::SMTP.start("localhost") do |smtp|
      smtp.send_message(email_message,  SENDER_EMAIL_ADDRESS, [RECIPIENT_EMAIL_ADDRESSES])
    end
  end
  
end


# Base class for URL tests. Subclasses should just override run_parse_test.
#
class UrlTest
  
  MAX_REQUEST_TIME = 30 # in seconds
  MAX_REQUEST_RETRIES = 2
  
  def initialize(url)
    @url = url
    @response_body = nil
    @error = nil
    @warning = nil # could potentially support multiple warnings
  end
  
  # fire up the tests
  def run_tests
    run_http_test
    if !@response_body.nil?
      run_parse_test # now if there's page-specific parsing to be done, do it
    end
    return !(@error or @warning).nil? # true if either is non-nil
  end
  
  # generic HTTP GETter with timeout & retries.
  def run_http_test
    retries = 0
    begin
      timeout(MAX_REQUEST_TIME) do
        Net::HTTP.get_response(URI.parse(@url)) do |http_response|
          if http_response.class == Net::HTTPOK # HTTPSuccess?
            @response_body = http_response.body
          else
            @error = "HTTP response code #{http_response.code}"
          end
        end
      end
    rescue TimeoutError
      # hey if this times out, any chance we leave a socket connection dangling?
      retry if (1..MAX_REQUEST_RETRIES) === (retries += 1)
    rescue Exception => e # SocketError
      @error = "Connection failed: #{e}"
    end
    if !retries.zero?
      if @response_body.nil?
        @error = "Request timed out #{retries-1} time(s) (more than #{MAX_REQUEST_TIME}s each time)"
      else
        # @warning = "Request took #{retries} retries" # don't warn about this: happens too often
      end
    end
  end
  
  # overriden by subclasses
  def run_parse_test
  end
  
  # for email output
  def format_results
    formatted_results = "Checking URL " + @url + " ...\n"
    if @error
      formatted_results += "\tERROR: " + @error + "\n"
    else
      if @warning
        formatted_results += "\tWARNING: " + @warning + "\n"
      end
      formatted_results += "\tOK\n"
    end
    return formatted_results
  end
  
end


class HealthCheckUrlTest < UrlTest
  def run_parse_test
    if @response_body != "OK"
      @error = "Health check failed (\"#{@response_body}\")"
    end
  end
end

class BJCheckUrlTest < UrlTest
  MAX_MINUTES_SINCE_JOB = 90
  
  def run_parse_test
    matches = @response_body.scan(/Most recent BJ job finished at ([^.]*)\./).flatten!
    if matches.nil?
      @error = "BJ Check is malformed"
    else
      last_job_time = Time.parse(matches.first)
      job_mins_ago = (Time.now - last_job_time) / 60
      if job_mins_ago > MAX_MINUTES_SINCE_JOB
        @warning = "Most recent BJ job finished at #{last_job_time} (#{job_mins_ago.round} mins ago)"
      end
    end
  end
end

class WidgetUrlTest < UrlTest
  def run_parse_test
    # nothing specific to test?
  end
end

# monkeypatch Symbol. akin to Rails' camelize().
# really seems like this should be core Ruby functionality...
class Symbol
  def to_camelcase
    self.to_s.split("_").each{ |p| p.capitalize! }.join
  end
end

# now kick off the whole process!
SiteMonitor.new
