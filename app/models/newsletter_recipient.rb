class NewsletterRecipient < ActiveRecord::Base
  belongs_to :newsletter
  belongs_to :member
end
