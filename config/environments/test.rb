# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# logging level debug during testing
config.log_level = :debug

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Cache store
FILE_CACHE_STORE_DIR = "#{RAILS_ROOT}/tmp/cache/"

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection    = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

ENV['RECAPTCHA_PUBLIC_KEY'] = 'PUBLIC_KEY'
ENV['RECAPTCHA_PRIVATE_KEY'] = 'PRIVATE_KEY'

# Load the mail blocker code
require 'mail_blocker'

# Override settings here ... send to no one!
ActionMailer::Base.send_to_nt_domain = false
ActionMailer::Base.nt_approved_recipients = [ ]

# Required for the newsletter & by the mailer
APP_DEFAULT_URL_OPTIONS = { :host => "localhost", :port => 3000 }

# We dont want to go to S3 while rspec tests
ATTACHMENT_FU_OPTIONS = { :basepath_prefix => "public/", :storage => :file_system }
