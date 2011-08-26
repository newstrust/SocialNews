class SocialNetworkFriendship < ActiveRecord::Base
  belongs_to :member

  # 2-letter social network codes
  FACEBOOK = "FB"
  TWITTER  = "TW"

  def self.friendships_are_symmetric?(network_code)
    case network_code
      when FACEBOOK then true
      when TWITTER then false
      else false
    end
  end

  def self.clear_friendships(network, member_id)
    delete_all(:network_code => network, :member_id => member_id)
    delete_all(:network_code => network, :friend_id => member_id)
  end

  def self.add_friendships(network, member, friends)
    attrs = {:network_code => network, :member_id => member.id}
    friends.each { |f|
      attrs[:friend_id] = f.id
      create(attrs) if !exists?(attrs)
    }

    # Create symmetric objects for symmetric friendship networks
    add_followers(network, member, friends) if friendships_are_symmetric?(network)
  end

  def self.add_followers(network, member, followers)
    attrs = {:network_code => network, :friend_id => member.id}
    followers.each { |f|
      attrs[:member_id] = f.id
      create(attrs) if !exists?(attrs)
    }
  end

  def self.friends(network, member_id)
    Member.find(:all,
                :joins => "JOIN social_network_friendships ON social_network_friendships.friend_id = members.id",
                :conditions => ["social_network_friendships.network_code = ? AND social_network_friendships.member_id = ?", network, member_id])
  end

  def self.facebook_friends(member_id)
    self.friends(FACEBOOK, member_id)
  end

  def self.twitter_friends(member_id)
    self.friends(TWITTER, member_id)
  end

  def self.are_friends?(network, m1, m2)
    exists?(:network_code => network, :member_id => m1.id, :friend_id => m2.id)
  end
end
