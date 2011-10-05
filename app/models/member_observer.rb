# These plugins extend the member model.
# However observers are initialized before the files in the lib directory are processed.
# Therefore we need to explicitly require them here first to avoid an exception.
# Thr gritty details are specified here:
# http://dev.rubyonrails.org/ticket/10969
require 'acts_as_taggable'
require 'acts_as_tagger'
require 'acts_as_processable'

class MemberObserver < ActiveRecord::Observer
  def after_create(member)
      # No need to send invitation email if fb-connected!
    return if member.fbc_linked?

    if !member.referred_by.blank? && Member.exists?(member.referred_by)
      Mailer.deliver_signup_invitation_notification(member)
    else
      # signed up through a partner
      if member.invitation
        Mailer.deliver_partner_signup_notification(member)
      else
        Mailer.deliver_signup_notification(member)
      end
    end
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception delivering signup notification to #{member.id}:#{member.name}; #{e}; #{e.backtrace.inspect}"
  end

    # Send fb or regular activation email, depending on how the activation was done
  def after_save(member)
    if member.recently_activated?
      member.fbc_linked? ? Mailer.deliver_fb_activation(member) : Mailer.deliver_activation(member)
    end

    # Remove all followed items once the member is terminated!
    if member.terminated?
      FollowedItem.destroy_all(:follower_id => member.id)
      FollowedItem.destroy_all(:followable_id => member.id, :followable_type => 'Member')
    end
  end

  def before_save(member)
    if member.muzzled_changed? && !member.new_record?
      member.comments.each{|x| x.update_attribute(:hidden_through_muzzle, member.muzzled?)}
    end
  end
end
