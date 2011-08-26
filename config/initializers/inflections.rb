# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format 
# (all these examples are active by default):
ActiveSupport::Inflector.inflections do |inflect|
   inflect.uncountable %w(social_group_attributes source_stats facebook_connect_settings twitter_settings)
   inflect.irregular 'save', 'saves'
end
