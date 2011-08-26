# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# logging level debug in development
config.log_level = :debug

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true
config.action_controller.perform_caching             = false

FILE_CACHE_STORE_DIR = "#{RAILS_ROOT}/tmp/cache/"
ActionController::Base.cache_store = :file_store, FILE_CACHE_STORE_DIR

ENV['RECAPTCHA_PUBLIC_KEY'] = '6Lf7Y8cSAAAAADRMfUX7hJkhasHGmRRC2S9b0CJd'
ENV['RECAPTCHA_PRIVATE_KEY'] = '6Lf7Y8cSAAAAANo92RT6VDtTgz_qjVd2Tt6r3q4o'

# Turn off email delivery!
config.action_mailer.perform_deliveries = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

# Load the mail blocker code
require 'mail_blocker'

# Override settings here ...
ActionMailer::Base.send_to_nt_domain = false
ActionMailer::Base.nt_approved_recipients = [ "sastry@cs.wisc.edu", "sss.lists@gmail.com", "david@electriceggplant.com", "adamflorin@gmail.com" ]

# Required for the newsletter & by the mailer
APP_DEFAULT_URL_OPTIONS = { :host => "localhost", :port => 3000 }

# We dont want to go onto S3 during development
ATTACHMENT_FU_OPTIONS = { :basepath_prefix => "public/", :storage => :file_system }
