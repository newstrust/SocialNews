class FollowedItem < ActiveRecord::Base
  belongs_to :follower, :class_name => "Member"
  belongs_to :followable, :polymorphic => true

  # Explicitly list all known polymorphic associations so that we can do member.followers, source.followers, etc in the opposite direction!
  belongs_to :member, :foreign_key => "followable_id", :class_name => "Member"
  belongs_to :topic,  :foreign_key => "followable_id", :class_name => "Topic"
  belongs_to :feed,   :foreign_key => "followable_id", :class_name => "Feed"
  belongs_to :source, :foreign_key => "followable_id", :class_name => "Source"

  def self.toggle(follower_id, followable_type, followable_id)
    fi = FollowedItem.find(:first, :conditions => {:follower_id => follower_id, :followable_type => followable_type, :followable_id => followable_id})
    if fi
      fi.destroy
      nil
    else
      FollowedItem.create(:follower_id => follower_id, :followable_type => followable_type, :followable_id => followable_id)
    end
  end

  def self.add_follow(follower_id, followable_type, followable_id)
    fi = FollowedItem.find(:first, :conditions => {:follower_id => follower_id, :followable_type => followable_type, :followable_id => followable_id})
    if fi.nil?
      FollowedItem.create(:follower_id => follower_id, :followable_type => followable_type, :followable_id => followable_id)
    end
  end

  def self.mutual_followers?(m1, m2)
       FollowedItem.exists?(:follower_id => m1.id, :followable_type => 'member', :followable_id => m2) \
    && FollowedItem.exists?(:follower_id => m2.id, :followable_type => 'member', :followable_id => m1.id)
  end
end
