class FollowedItemObserver < ActiveRecord::Observer
  include MynewsHelper
  def after_create(followed_item)
    if followed_item.followable_type.downcase == 'member'
      follower = followed_item.follower
      followee = Member.find(followed_item.followable_id)
      if followee.email_notification_preferences.followed_member
        NotificationMailer.deliver_followed_member({ 
          :to_member => followee,
          :body => {:to => followee, :follower => follower}})
      end
    end
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception delivering notification for #{followed_item.id}; #{e}; #{e.backtrace.inspect}"
  end
end
