class Sharable < ActiveRecord::Base
  # polymorphic has_many :throughs... see http://blog.hasmanythrough.com/2006/4/3/polymorphic-through
  belongs_to :member
  belongs_to :sharable, :polymorphic => :true
  belongs_to :review, :foreign_key => "sharable_id", :class_name => "Review"

    # 2-letter codes for share target
  FACEBOOK = SocialNetworkFriendship::FACEBOOK
  TWITTER  = SocialNetworkFriendship::TWITTER
end
