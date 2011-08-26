# SiteConstants
#
# For hard-coded constants that dont need to be tweaked often + for constants loaded from the .yml files
#
# A lot of these had to be ordered hashes (as they drive pull-down menus), but those won't exist till Ruby 1.9
# So we kinda jump through hoops with YML file format and a lot of bizarre query code to get around this.
#
# N.B.: SocialNewsConfig is defined in config/initializers/site_constants.rb so that it has global scope... ugh

require 'yaml'

module SiteConstants
  # Move constants from different controllers in here.
  NUM_ACTIVITY_ENTRIES_PER_FETCH = 20

  class << self
    CONSTANTS_BASE_PATH = "#{RAILS_ROOT}/config/social_news_constants/"
    
    def load_constants
      Dir.entries(CONSTANTS_BASE_PATH).reject{ |fn| fn =~ /^\./ }.each do |fn|
        SocialNewsConfig.update(YAML.load(File.read(CONSTANTS_BASE_PATH + fn)))
      end
    end
    
    def ordered_hash(key)
      constants_hash_to_ordered_hash(SocialNewsConfig[key])
    end
    
    
    private
      
      def constants_hash_to_ordered_hash(ch)
        oh = ActiveSupport::OrderedHash.new
        ch.each{|o| oh[o.keys.first] = o.values.first}
        return oh
      end
      
  end
end

# Also, we'd expect select to return an OrderedHash, not an Array!!! monkeypatch
module ActiveSupport
  class OrderedHash
    def select(&block)
      ActiveSupport::OrderedHash[super(&block)]
    end
  end
end
