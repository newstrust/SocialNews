# SSS: Keep this code free of rails dependencies so that it can execute as regular ruby code.
module FacebookConnect
  if !defined?(SocialNewsConfig)
    require 'yaml'
    mydir = File.dirname(__FILE__)
    RAILS_ROOT = "#{mydir}/.."
    RAILS_ENV = FeedParser.rails_env
  end

  class MissingPermissions < StandardError; end

  facebook_config = "#{RAILS_ROOT}/config/facebook.yml"
  if File.exists?(facebook_config)
    fbc_config = YAML.load(File.read(facebook_config))[RAILS_ENV]
    FBC_APP_ID     = fbc_config["app_id"]
    FBC_SECRET_KEY = fbc_config["secret_key"]
  end

  # SSS FIXME: This no longer works!  Dont use this
  def self.fb_activity_stream_url(dummy_url)
    fb_uid, sess_key = $1, $2 if dummy_url =~ %r|dummy_newsfeed_url/(.*)/(.*)|
    query_params = { "app_id" => FBC_APP_ID, "session_key" => sess_key, "source_id" => fb_uid }
    query_params.merge!({"v" => "0.7", "sig" => fb_get_request_sig(query_params)})
    url_string = query_params.inject("") { |s,k| s + "#{k[0]}=#{k[1]}&" }
    "http://www.facebook.com/activitystreams/feed.php?#{url_string}read"
  end

  private

  # SSS FIXME: Old code. Not sure this is necessary anymore or used anywhere else
  require 'digest/md5'
  def self.fb_get_request_sig(args)
      # Sort argument array alphabetically by key, then append everything as "k=v", except the signature itself (obviously)
    args_str = args.sort {|x,y| x[0] <=> y[0] }.inject("") { |buf,a| buf + (a[0] == "req_sig" ? "" : "#{a[0]}=#{a[1]}") }

      # Append the secret key and compute the md5 hash of the string
    Digest::MD5.hexdigest(args_str + FBC_SECRET_KEY)
  end
end
