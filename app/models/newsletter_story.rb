class NewsletterStory < ActiveRecord::Base
  belongs_to :newsletter
  belongs_to :story
end
