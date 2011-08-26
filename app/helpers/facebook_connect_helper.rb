module FacebookConnectHelper
  include Facebooker::Rails::Helpers::FbConnect

  def fb_friends_on_nt
    fbs = facebook_session
    return [] if !fbs

    app_friends = fbs.user.friends_with_this_app
    return [] if app_friends.blank?

    Member.find(:all, :joins => :facebook_connect_settings, :conditions => ["facebook_connect_settings.fb_uid IN (?)", app_friends.map(&:to_s)])
  rescue # Timeouts, exceptions, whatever!
    []
  end

  def fbc_session_user_friends_with?(m2)
    current_member.fbc_friends_with?(m2, facebook_session)
    #m1 && m1.fbc_linked? && m2.fbc_linked? && facebook_session && facebook_session.user.friends_with?(m2.fb_uid)
  rescue Exception => e # Timeouts, exceptions, whatever!
    logger.error "ERROR fetching facebook friendship info for #{current_member.id} and #{m2.id}!  Exception: #{e}; Backtrace: #{e.backtrace.inspect}"
    false
  end
end
