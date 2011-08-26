class StoryFeed < ActiveRecord::Base
  belongs_to :story
  belongs_to :feed
end
