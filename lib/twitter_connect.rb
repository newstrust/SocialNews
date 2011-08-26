module TwitterConnect
  if !defined?(SocialNewsConfig)
    require 'yaml'
    mydir = File.dirname(__FILE__)
    RAILS_ROOT = "#{mydir}/.."
    RAILS_ENV = FeedParser.rails_env
    require 'twitter'
  end

  twitter_config = "#{RAILS_ROOT}/config/twitter.yml"
  @@oauth_config = YAML.load(File.read(twitter_config))[RAILS_ENV] if File.exists?(twitter_config)

  def self.authed_twitter_client(dummy_url)
    access_token, secret_token = $1, $2 if dummy_url =~ %r|dummy_newsfeed_url/(.*)/(.*)|
    oauth = Twitter::OAuth.new(@@oauth_config['consumer_key'], @@oauth_config['consumer_secret'])
    oauth.authorize_from_access(access_token, secret_token)
    Twitter::Base.new(oauth)
  end
end
