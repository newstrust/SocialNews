module FacebookConnectHelper
  def fbc_session_user_friends_with?(m2)
    current_member.fbc_friends_with?(m2, facebook_session)
  rescue Exception => e # Timeouts, exceptions, whatever!
    logger.error "ERROR fetching facebook friendship info for #{current_member.id} and #{m2.id}!  Exception: #{e}; Backtrace: #{e.backtrace.inspect}"
    false
  end
end
