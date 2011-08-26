# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# logging level warn in production
config.log_level = :warn

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

# Enable a file store for the fragment cache!
FILE_CACHE_STORE_DIR = "#{RAILS_ROOT}/tmp/cache/"
ActionController::Base.cache_store = :file_store, FILE_CACHE_STORE_DIR 

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

# From http://forum.engineyard.com/forums/1/topics/27
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  :perform_deliveries => true,
  :address => 'smtp.sendgrid.net',
  :port => 25,
  :domain => "domain-here",
  :authentication => :plain,
  :user_name      => 'user-id-here',
  :password       => 'password-here'
}

# RubyInline makes us jump through hoops (indirectly ImageScience's fault)
# see http://www.viget.com/extend/rubyinline-in-shared-rails-environments/
tmp_dir = "#{RAILS_ROOT}/tmp"
`chmod g-w #{tmp_dir}`
ENV['INLINEDIR'] = tmp_dir

ENV['RECAPTCHA_PUBLIC_KEY'] = '6Lf7Y8cSAAAAADRMfUX7hJkhasHGmRRC2S9b0CJd'
ENV['RECAPTCHA_PRIVATE_KEY'] = '6Lf7Y8cSAAAAANo92RT6VDtTgz_qjVd2Tt6r3q4o'

# Required for the newsletter, mailer, and feed fetcher
APP_DEFAULT_URL_OPTIONS = { :host => "socialnews.net" }

# Nothing new required
ATTACHMENT_FU_OPTIONS = { }
