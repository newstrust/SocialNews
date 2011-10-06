module SessionsHelper
    # Used by regular logout code as well as facebook logout code
  def delete_session
    self.current_member.forget_me if logged_in? # not in use
    cookies.delete :auth_token
    reset_session
  end
end
