# The twitter_oauth gem loads 'json' which clobbers ActiveSupport's to_json implementation 
# So, add in json gem's patch of active support's to_json implementation!
require 'json/add/rails'
