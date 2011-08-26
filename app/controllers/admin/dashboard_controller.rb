class Admin::DashboardController < ApplicationController
  before_filter :login_required
  grant_access_to [:admin, :editor, :newshound]
  layout 'admin'
  
  def index
  end
  
end